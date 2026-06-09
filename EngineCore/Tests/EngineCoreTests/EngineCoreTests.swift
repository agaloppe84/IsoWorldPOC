import XCTest
@testable import EngineCore

final class EngineCoreTests: XCTestCase {
    func testWorldSeedStoresRawValue() {
        let seed = WorldSeed(42)

        XCTAssertEqual(seed.value, 42)
    }

    func testChunkCoordinateStoresAxesAndOffsets() {
        let coordinate = ChunkCoordinate(x: 3, y: 1, z: -2)

        XCTAssertEqual(coordinate.x, 3)
        XCTAssertEqual(coordinate.y, 1)
        XCTAssertEqual(coordinate.z, -2)
        XCTAssertEqual(
            coordinate.offsetBy(x: -1, y: 2, z: 5),
            ChunkCoordinate(x: 2, y: 3, z: 3)
        )
    }

    func testPositiveWorldPositionStaysInOriginChunk() {
        let position = WorldPosition(x: 4.25, y: 2.0, z: 15.75)
        let chunk = ChunkCoordinate.containing(position, chunkSize: 16)
        let local = chunk.localCoordinate(for: position, chunkSize: 16)

        XCTAssertEqual(chunk, ChunkCoordinate(x: 0, y: 0, z: 0))
        XCTAssertEqual(local.x, 4.25, accuracy: 0.0001)
        XCTAssertEqual(local.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(local.z, 15.75, accuracy: 0.0001)
    }

    func testWorldPositionBeyondOneChunkMapsToExpectedChunk() {
        let position = WorldPosition(x: 18.5, y: 41.0, z: 63.99)
        let chunk = ChunkCoordinate.containing(position, chunkSize: 16)
        let local = chunk.localCoordinate(for: position, chunkSize: 16)

        XCTAssertEqual(chunk, ChunkCoordinate(x: 1, y: 2, z: 3))
        XCTAssertEqual(local.x, 2.5, accuracy: 0.0001)
        XCTAssertEqual(local.y, 9.0, accuracy: 0.0001)
        XCTAssertEqual(local.z, 15.99, accuracy: 0.0001)
    }

    func testNegativeWorldPositionUsesFloorChunkCoordinates() {
        let position = WorldPosition(x: -0.25, y: -16.25, z: -32.0)
        let chunk = ChunkCoordinate.containing(position, chunkSize: 16)
        let local = chunk.localCoordinate(for: position, chunkSize: 16)

        XCTAssertEqual(chunk, ChunkCoordinate(x: -1, y: -2, z: -2))
        XCTAssertEqual(local.x, 15.75, accuracy: 0.0001)
        XCTAssertEqual(local.y, 15.75, accuracy: 0.0001)
        XCTAssertEqual(local.z, 0.0, accuracy: 0.0001)
    }

    func testWorldPositionExactlyOnChunkBoundary() {
        let position = WorldPosition(x: 16.0, y: -16.0, z: 0.0)
        let chunk = ChunkCoordinate.containing(position, chunkSize: 16)
        let local = chunk.localCoordinate(for: position, chunkSize: 16)

        XCTAssertEqual(chunk, ChunkCoordinate(x: 1, y: -1, z: 0))
        XCTAssertEqual(local.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(local.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(local.z, 0.0, accuracy: 0.0001)
    }

    func testWorldPositionChunkConversionsAreStable() {
        let position = WorldPosition(x: -18.25, y: 5.5, z: 32.5)
        let chunk = ChunkCoordinate.containing(position, chunkSize: 16)
        let local = chunk.localCoordinate(for: position, chunkSize: 16)
        let reconstructed = chunk.worldPosition(for: local, chunkSize: 16)

        XCTAssertEqual(chunk, ChunkCoordinate(x: -2, y: 0, z: 2))
        XCTAssertEqual(reconstructed.x, position.x, accuracy: 0.0001)
        XCTAssertEqual(reconstructed.y, position.y, accuracy: 0.0001)
        XCTAssertEqual(reconstructed.z, position.z, accuracy: 0.0001)
        XCTAssertEqual(ChunkCoordinate.containing(reconstructed, chunkSize: 16), chunk)
        XCTAssertEqual(
            ChunkCoordinate.localCoordinate(for: reconstructed, chunkSize: 16),
            local
        )
    }

    func testChunkStreamingRadiusOneRequiresNineChunks() {
        let planner = ChunkStreamingPlanner(activeRadius: 1)
        let requiredChunks = planner.requiredChunks(around: .origin)

        XCTAssertEqual(requiredChunks.count, 9)
        XCTAssertTrue(requiredChunks.contains(ChunkCoordinate(x: -1, y: 0, z: -1)))
        XCTAssertTrue(requiredChunks.contains(.origin))
        XCTAssertTrue(requiredChunks.contains(ChunkCoordinate(x: 1, y: 0, z: 1)))
    }

    func testChunkStreamingPlanLoadsMissingChunks() {
        let planner = ChunkStreamingPlanner(activeRadius: 1)
        let loadedChunks: Set<ChunkCoordinate> = [.origin]
        let plan = planner.plan(currentChunk: .origin, loadedChunks: loadedChunks)

        XCTAssertEqual(plan.requiredChunks.count, 9)
        XCTAssertEqual(plan.chunksToLoad.count, 8)
        XCTAssertEqual(plan.chunksToKeep, loadedChunks)
        XCTAssertTrue(plan.chunksToUnload.isEmpty)
    }

    func testChunkStreamingPlanDoesNothingWhenChunkSetIsAlreadyCurrent() {
        let planner = ChunkStreamingPlanner(activeRadius: 1)
        let loadedChunks = planner.requiredChunks(around: .origin)
        let plan = planner.plan(currentChunk: .origin, loadedChunks: loadedChunks)

        XCTAssertTrue(plan.chunksToLoad.isEmpty)
        XCTAssertTrue(plan.chunksToUnload.isEmpty)
        XCTAssertEqual(plan.chunksToKeep, loadedChunks)
    }

    func testChunkStreamingPlanMovesOneChunkEast() {
        let planner = ChunkStreamingPlanner(activeRadius: 1)
        let oldChunks = planner.requiredChunks(around: .origin)
        let newCenter = ChunkCoordinate(x: 1, y: 0, z: 0)
        let plan = planner.plan(currentChunk: newCenter, loadedChunks: oldChunks)

        XCTAssertEqual(plan.chunksToLoad.count, 3)
        XCTAssertEqual(plan.chunksToUnload.count, 3)
        XCTAssertTrue(plan.chunksToLoad.contains(ChunkCoordinate(x: 2, y: 0, z: -1)))
        XCTAssertTrue(plan.chunksToLoad.contains(ChunkCoordinate(x: 2, y: 0, z: 0)))
        XCTAssertTrue(plan.chunksToLoad.contains(ChunkCoordinate(x: 2, y: 0, z: 1)))
        XCTAssertTrue(plan.chunksToUnload.contains(ChunkCoordinate(x: -1, y: 0, z: -1)))
        XCTAssertTrue(plan.chunksToUnload.contains(ChunkCoordinate(x: -1, y: 0, z: 0)))
        XCTAssertTrue(plan.chunksToUnload.contains(ChunkCoordinate(x: -1, y: 0, z: 1)))
    }

    func testChunkStreamingPlanSupportsNegativeChunkCoordinates() {
        let planner = ChunkStreamingPlanner(activeRadius: 1)
        let currentChunk = ChunkCoordinate(x: -2, y: 0, z: -3)
        let requiredChunks = planner.requiredChunks(around: currentChunk)

        XCTAssertEqual(requiredChunks.count, 9)
        XCTAssertTrue(requiredChunks.contains(ChunkCoordinate(x: -3, y: 0, z: -4)))
        XCTAssertTrue(requiredChunks.contains(currentChunk))
        XCTAssertTrue(requiredChunks.contains(ChunkCoordinate(x: -1, y: 0, z: -2)))
    }

    func testSeededRandomIsDeterministicForSameSeed() {
        var first = SeededRandom(seed: WorldSeed(123_456))
        var second = SeededRandom(seed: WorldSeed(123_456))

        let firstValues = (0..<8).map { _ in first.next() }
        let secondValues = (0..<8).map { _ in second.next() }

        XCTAssertEqual(firstValues, secondValues)
    }

    func testSeededRandomDiffersForDifferentSeeds() {
        var first = SeededRandom(seed: WorldSeed(1))
        var second = SeededRandom(seed: WorldSeed(2))

        XCTAssertNotEqual(first.next(), second.next())
    }

    func testChunkGeneratorProduces64By64Heightmap() {
        let generator = ChunkGenerator(seed: WorldSeed(42))
        let heightmap = generator.generateHeightmap(for: .origin)

        XCTAssertEqual(ChunkHeightmap.resolution, 64)
        XCTAssertEqual(heightmap.samples.count, 64 * 64)
        XCTAssertEqual(heightmap[0, 0].localX, 0)
        XCTAssertEqual(heightmap[63, 63].localZ, 63)
        XCTAssertTrue(heightmap[12, 34].height.isFinite)
    }

    func testChunkGeneratorIsDeterministicForSameSeedAndChunk() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let first = ChunkGenerator(seed: WorldSeed(99)).generateHeightmap(for: coordinate)
        let second = ChunkGenerator(seed: WorldSeed(99)).generateHeightmap(for: coordinate)

        XCTAssertEqual(first.samples, second.samples)
        XCTAssertEqual(first.stableHash, second.stableHash)
    }

    func testChunkGeneratorDiffersForDifferentSeeds() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let first = ChunkGenerator(seed: WorldSeed(99)).generateHeightmap(for: coordinate)
        let second = ChunkGenerator(seed: WorldSeed(100)).generateHeightmap(for: coordinate)

        XCTAssertNotEqual(first.samples, second.samples)
        XCTAssertNotEqual(first.stableHash, second.stableHash)
    }

    func testChunkGeneratorDiffersForDifferentChunks() {
        let generator = ChunkGenerator(seed: WorldSeed(99))
        let first = generator.generateHeightmap(for: ChunkCoordinate(x: 2, y: 0, z: -3))
        let second = generator.generateHeightmap(for: ChunkCoordinate(x: 3, y: 0, z: -3))

        XCTAssertNotEqual(first.samples, second.samples)
        XCTAssertNotEqual(first.stableHash, second.stableHash)
    }

    func testBiomeDefinitionsExposePlaceholderMaterialData() {
        for type in BiomeType.allCases {
            let biome = Biome.definition(for: type)

            XCTAssertEqual(biome.type, type)
            XCTAssertFalse(biome.materialIdentifier.isEmpty)
            XCTAssertGreaterThanOrEqual(biome.placeholderColor.red, 0)
            XCTAssertLessThanOrEqual(biome.placeholderColor.red, 1)
            XCTAssertGreaterThanOrEqual(biome.placeholderColor.green, 0)
            XCTAssertLessThanOrEqual(biome.placeholderColor.green, 1)
            XCTAssertGreaterThanOrEqual(biome.placeholderColor.blue, 0)
            XCTAssertLessThanOrEqual(biome.placeholderColor.blue, 1)
            XCTAssertGreaterThan(biome.ruggednessMultiplier, 0)
        }
    }

    func testBiomeSamplerIsDeterministicForSameSeedAndPosition() {
        let position = WorldPosition(x: 125.25, y: 0, z: -61.75)
        let first = BiomeSampler(seed: WorldSeed(42)).biome(at: position)
        let second = BiomeSampler(seed: WorldSeed(42)).biome(at: position)

        XCTAssertEqual(first, second)
    }

    func testBiomeSamplerChangesAcrossWorldPositions() {
        let sampler = BiomeSampler(seed: WorldSeed(42))
        let sampledTypes = biomeTypes(
            sampler: sampler,
            positions: [
                WorldPosition(x: -512, y: 0, z: -512),
                WorldPosition(x: -128, y: 0, z: 256),
                WorldPosition(x: 0, y: 0, z: 0),
                WorldPosition(x: 192, y: 0, z: -320),
                WorldPosition(x: 512, y: 0, z: 384),
                WorldPosition(x: 896, y: 0, z: -640),
            ]
        )

        XCTAssertGreaterThan(sampledTypes.count, 1)
    }

    func testBiomeSamplerChangesAcrossSeeds() {
        let positions = [
            WorldPosition(x: -384, y: 0, z: -384),
            WorldPosition(x: -192, y: 0, z: 128),
            WorldPosition(x: 96, y: 0, z: -256),
            WorldPosition(x: 384, y: 0, z: 448),
            WorldPosition(x: 704, y: 0, z: -96),
        ]
        let first = biomeTypes(sampler: BiomeSampler(seed: WorldSeed(1)), positions: positions)
        let second = biomeTypes(sampler: BiomeSampler(seed: WorldSeed(2)), positions: positions)

        XCTAssertNotEqual(first, second)
    }

    func testBiomeSamplerIsStableForChunkLocalCoordinates() {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        let coordinate = ChunkCoordinate(x: -3, y: 0, z: 4)
        let first = sampler.biome(for: coordinate, localX: 12, localZ: 48)
        let second = sampler.biome(for: coordinate, localX: 12, localZ: 48)
        let dominant = sampler.dominantBiome(for: coordinate)

        XCTAssertEqual(first, second)
        XCTAssertEqual(dominant, sampler.biome(for: coordinate, localX: 32, localZ: 32))
    }

    func testTerrainMeshBuilderProducesOneVertexPerHeightmapSample() {
        let heightmap = ChunkGenerator(seed: WorldSeed(42)).generateHeightmap(for: .origin)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(mesh.vertices.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(mesh.normals.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(mesh.uvs.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(mesh.vertices.first, TerrainMesh.Vertex(x: 0, y: heightmap[0, 0].height, z: 0))
        XCTAssertEqual(mesh.vertices.last, TerrainMesh.Vertex(x: 63, y: heightmap[63, 63].height, z: 63))
    }

    func testTerrainMeshBuilderProducesExpectedTriangleIndices() {
        let heightmap = ChunkGenerator(seed: WorldSeed(42)).generateHeightmap(for: .origin)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)
        let expectedQuadCount = (ChunkHeightmap.resolution - 1) * (ChunkHeightmap.resolution - 1)

        XCTAssertEqual(mesh.indices.count, expectedQuadCount * 6)
        XCTAssertEqual(mesh.indices.prefix(6), [0, 64, 1, 1, 64, 65])
    }

    func testTerrainMeshBuilderProducesUpNormalsForFlatHeightmap() {
        let heightmap = flatHeightmap(height: 0)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(mesh.normals.first, TerrainMesh.Normal(x: 0, y: 1, z: 0))
        XCTAssertEqual(mesh.normals[ChunkHeightmap.resolution + 1], TerrainMesh.Normal(x: 0, y: 1, z: 0))
        XCTAssertEqual(mesh.normals.last, TerrainMesh.Normal(x: 0, y: 1, z: 0))
    }

    func testTerrainMeshBuilderProducesNormalizedNormals() {
        let heightmap = ChunkGenerator(seed: WorldSeed(42)).generateHeightmap(for: .origin)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)

        for normal in [mesh.normals[0], mesh.normals[65], mesh.normals[ChunkHeightmap.sampleCount - 1]] {
            let length = (normal.x * normal.x + normal.y * normal.y + normal.z * normal.z).squareRoot()

            XCTAssertEqual(length, 1, accuracy: 0.0001)
            XCTAssertGreaterThan(normal.y, 0)
        }
    }

    func testTerrainSamplerReturnsExactGridHeights() {
        let sampler = TerrainSampler(geometry: rampGeometry(horizontalScale: 1, verticalScale: 1))

        XCTAssertEqual(sampler.heightAt(x: 0, z: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(sampler.heightAt(x: 3, z: 4), 22, accuracy: 0.0001)
    }

    func testTerrainSamplerBilinearlyInterpolatesBetweenGridHeights() {
        let sampler = TerrainSampler(geometry: rampGeometry(horizontalScale: 1, verticalScale: 1))

        XCTAssertEqual(sampler.heightAt(x: 0.5, z: 0.5), 3, accuracy: 0.0001)
    }

    func testTerrainSamplerAppliesScaleAndOrigin() {
        let sampler = TerrainSampler(
            geometry: rampGeometry(horizontalScale: 0.5, verticalScale: 2),
            originX: -10,
            originZ: 5
        )

        XCTAssertEqual(sampler.heightAt(x: -9.5, z: 6), 20, accuracy: 0.0001)
    }

    func testTerrainSamplerReportsFlatSlopeAsZero() {
        let sampler = TerrainSampler(geometry: flatGeometry(height: 3, horizontalScale: 1))

        XCTAssertEqual(sampler.slopeAt(x: 20, z: 20), 0, accuracy: 0.0001)
    }

    func testTerrainSamplerReportsSlopeForRamps() {
        let sampler = TerrainSampler(geometry: rampGeometry(horizontalScale: 1, verticalScale: 1))
        let sample = sampler.sampleAt(x: 20, z: 20)

        XCTAssertEqual(sample.height, 120, accuracy: 0.0001)
        XCTAssertGreaterThan(sample.slope, 0)
    }

    private func flatHeightmap(height: Float) -> ChunkHeightmap {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                samples.append(
                    TerrainSample(
                        localX: localX,
                        localZ: localZ,
                        worldX: localX,
                        worldZ: localZ,
                        height: height
                    )
                )
            }
        }

        return ChunkHeightmap(seed: WorldSeed(1), coordinate: .origin, samples: samples)
    }

    private func rampHeightmap() -> ChunkHeightmap {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                samples.append(
                    TerrainSample(
                        localX: localX,
                        localZ: localZ,
                        worldX: localX,
                        worldZ: localZ,
                        height: Float(localX * 2 + localZ * 4)
                    )
                )
            }
        }

        return ChunkHeightmap(seed: WorldSeed(1), coordinate: .origin, samples: samples)
    }

    private func flatGeometry(height: Float, horizontalScale: Float) -> TerrainGeometryBuffers {
        TerrainGeometryBuffers(
            resolution: ChunkHeightmap.resolution,
            positions: terrainPositions(horizontalScale: horizontalScale) { _, _ in height },
            normals: [],
            textureCoordinates: [],
            indices: []
        )
    }

    private func rampGeometry(horizontalScale: Float, verticalScale: Float) -> TerrainGeometryBuffers {
        TerrainGeometryBuffers(
            resolution: ChunkHeightmap.resolution,
            positions: terrainPositions(horizontalScale: horizontalScale) { localX, localZ in
                Float(localX * 2 + localZ * 4) * verticalScale
            },
            normals: [],
            textureCoordinates: [],
            indices: []
        )
    }

    private func terrainPositions(
        horizontalScale: Float,
        height: (_ localX: Int, _ localZ: Int) -> Float
    ) -> [TerrainGeometryBuffers.Position] {
        var positions: [TerrainGeometryBuffers.Position] = []
        positions.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                positions.append(
                    TerrainGeometryBuffers.Position(
                        x: Float(localX) * horizontalScale,
                        y: height(localX, localZ),
                        z: Float(localZ) * horizontalScale
                    )
                )
            }
        }

        return positions
    }

    private func biomeTypes(
        sampler: BiomeSampler,
        positions: [WorldPosition]
    ) -> Set<BiomeType> {
        Set(positions.map { sampler.biome(at: $0).type })
    }
}
