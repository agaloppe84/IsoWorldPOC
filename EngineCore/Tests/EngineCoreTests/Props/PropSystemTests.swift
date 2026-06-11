import XCTest
@testable import EngineCore

final class PropSystemTests: XCTestCase {
    func testNaturalV1CatalogCoversStep11PropTypes() {
        XCTAssertEqual(
            Set(PropCatalog.naturalV1.supportedTypes),
            Set([.rock, .pebble, .grass, .tree, .deadwood, .crystal])
        )
    }

    func testPropSystemIsDeterministicForSameSeedChunkAndTerrainGrid() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -1)
        let biome = Biome.definition(for: .temperateForest)
        let grid = sampleGrid(
            coordinate: coordinate,
            biome: biome,
            slope: 0.18,
            moisture: 0.65,
            walkability: 0.92
        )
        let system = PropSystem(seed: WorldSeed(42), maxPropsPerChunk: 16)

        let first = system.chunkData(for: coordinate, biome: biome, terrainSampleGrid: grid)
        let second = system.chunkData(for: coordinate, biome: biome, terrainSampleGrid: grid)

        XCTAssertEqual(first, second)
        XCTAssertFalse(first.recipes.isEmpty)
    }

    func testPropSystemUsesSlopeMoistureAndWalkabilityRules() {
        let catalog = PropCatalog(
            identifier: "test.grass.only",
            rules: [
                PropPlacementRule(
                    type: .grass,
                    baseWeight: 1,
                    biomeWeights: [.grassland: 1],
                    slopeRange: PropValueRange(0, 0.20),
                    moistureRange: PropValueRange(0.50, 1),
                    walkabilityRange: PropValueRange(0.70, 1)
                )
            ]
        )
        let system = PropSystem(seed: WorldSeed(7), catalog: catalog, maxPropsPerChunk: 12)
        let biome = Biome.definition(for: .grassland)
        let friendlyGrid = sampleGrid(
            biome: biome,
            slope: 0.08,
            moisture: 0.78,
            walkability: 0.96
        )
        let rejectedGrid = sampleGrid(
            biome: biome,
            slope: 0.72,
            moisture: 0.20,
            walkability: 0.35
        )

        let friendly = system.chunkData(for: .origin, biome: biome, terrainSampleGrid: friendlyGrid)
        let rejected = system.chunkData(for: .origin, biome: biome, terrainSampleGrid: rejectedGrid)

        XCTAssertFalse(friendly.recipes.isEmpty)
        XCTAssertTrue(friendly.recipes.allSatisfy { $0.placement.type == .grass })
        XCTAssertTrue(rejected.recipes.isEmpty)
    }

    func testPropSystemAssignsUniqueStableIDsAndGridStrideWorldCoordinates() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let biome = Biome.definition(for: .coast)
        let grid = sampleGrid(
            coordinate: coordinate,
            biome: biome,
            slope: 0.12,
            moisture: 0.62,
            walkability: 0.88
        )
        let data = PropSystem(seed: WorldSeed(99), maxPropsPerChunk: 10)
            .chunkData(for: coordinate, biome: biome, terrainSampleGrid: grid)
        let ids = Set(data.recipes.map(\.stableID))
        let minWorldX = Float(coordinate.x * ChunkHeightmap.gridStride)
        let maxWorldX = minWorldX + Float(ChunkHeightmap.resolution - 1)
        let minWorldZ = Float(coordinate.z * ChunkHeightmap.gridStride)
        let maxWorldZ = minWorldZ + Float(ChunkHeightmap.resolution - 1)

        XCTAssertEqual(ids.count, data.recipes.count)

        for placement in data.placements {
            XCTAssertGreaterThanOrEqual(placement.worldX, minWorldX)
            XCTAssertLessThanOrEqual(placement.worldX, maxWorldX)
            XCTAssertGreaterThanOrEqual(placement.worldZ, minWorldZ)
            XCTAssertLessThanOrEqual(placement.worldZ, maxWorldZ)
        }
    }

    func testProceduralAssetGeneratorUsesNaturalShapes() {
        let generator = ProceduralAssetGenerator(seed: WorldSeed(42))
        let biome = Biome.definition(for: .temperateForest)

        XCTAssertTrue(shapes(for: .rock, generator: generator, biome: biome).contains(.capsule))
        XCTAssertTrue(shapes(for: .pebble, generator: generator, biome: biome).contains(.capsule))
        XCTAssertTrue(shapes(for: .grass, generator: generator, biome: biome).contains(.cone))
        XCTAssertTrue(shapes(for: .tree, generator: generator, biome: biome).contains(.capsule))
        XCTAssertTrue(shapes(for: .deadwood, generator: generator, biome: biome).contains(.capsule))
        XCTAssertTrue(shapes(for: .crystal, generator: generator, biome: biome).contains(.cone))
    }

    private func shapes(
        for type: PropType,
        generator: ProceduralAssetGenerator,
        biome: Biome
    ) -> Set<PropGeometryShape> {
        let variant = generator.variant(
            for: PropPlacement(
                placementIndex: 0,
                type: type,
                localX: 8,
                localZ: 8,
                worldX: 8,
                worldZ: 8,
                rotationRadians: 0,
                scale: 1
            ),
            biome: biome,
            chunk: .origin
        )

        return Set(variant.geometry.parts.map(\.shape))
    }

    private func sampleGrid(
        coordinate: ChunkCoordinate = .origin,
        biome: Biome,
        slope: Float,
        moisture: Float,
        walkability: Float
    ) -> TerrainSampleGrid {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                samples.append(TerrainSample(
                    localX: localX,
                    localZ: localZ,
                    worldX: coordinate.x * ChunkHeightmap.gridStride + localX,
                    worldZ: coordinate.z * ChunkHeightmap.gridStride + localZ,
                    height: 0,
                    slope: slope,
                    moisture: moisture,
                    temperature: 0.55,
                    materialWeights: MaterialWeights(primaryBiome: biome),
                    walkability: walkability
                ))
            }
        }

        return TerrainSampleGrid(
            seed: WorldSeed(123),
            coordinate: coordinate,
            samples: samples
        )
    }
}
