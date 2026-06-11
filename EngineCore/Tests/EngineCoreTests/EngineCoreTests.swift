import Foundation
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

    func testDefaultLightingStateIsStable() {
        let lighting = LightingState.defaultDay

        XCTAssertEqual(lighting.sunDirection.x, -0.35, accuracy: 0.0001)
        XCTAssertEqual(lighting.sunDirection.y, -0.85, accuracy: 0.0001)
        XCTAssertEqual(lighting.sunDirection.z, -0.25, accuracy: 0.0001)
        XCTAssertEqual(lighting.sunIntensity, 0.90, accuracy: 0.0001)
        XCTAssertEqual(lighting.ambientIntensity, 0.38, accuracy: 0.0001)
        XCTAssertFalse(lighting.shadowsEnabled)
    }

    func testRenderWorldSnapshotStoresLightingState() {
        let camera = CameraRenderState(
            position: WorldPosition(x: 0, y: 8, z: 10),
            target: WorldPosition(x: 0, y: 0, z: 0),
            fieldOfViewDegrees: 35,
            yaw: 0,
            pitch: -0.8,
            distance: 12
        )
        let lighting = LightingState(
            sunDirection: PropVector3(x: 0, y: -1, z: 0),
            sunIntensity: 0.7,
            ambientIntensity: 0.2,
            shadowsEnabled: true
        )
        let snapshot = RenderWorldSnapshot(
            camera: camera,
            lighting: lighting,
            chunks: [],
            debugOptions: RenderDebugOptions(showChunkBounds: true)
        )

        XCTAssertEqual(snapshot.lighting, lighting)
        XCTAssertEqual(snapshot.camera, camera)
        XCTAssertTrue(snapshot.debugOptions.showChunkBounds)
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

    func testChunkGeneratorSharesBorderSamplesBetweenAdjacentChunks() {
        let generator = ChunkGenerator(seed: WorldSeed(99))
        let left = generator.generateHeightmap(for: .origin)
        let right = generator.generateHeightmap(for: ChunkCoordinate(x: 1, y: 0, z: 0))
        let back = generator.generateHeightmap(for: ChunkCoordinate(x: 0, y: 0, z: 1))
        let negativeLeft = generator.generateHeightmap(for: ChunkCoordinate(x: -2, y: 0, z: -3))
        let negativeRight = generator.generateHeightmap(for: ChunkCoordinate(x: -1, y: 0, z: -3))

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                left.height(localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                right.height(localX: 0, localZ: localZ),
                accuracy: 0.0001
            )
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                left.height(localX: localX, localZ: ChunkHeightmap.resolution - 1),
                back.height(localX: localX, localZ: 0),
                accuracy: 0.0001
            )
        }

        for localZ in [0, 29, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                negativeLeft.height(localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                negativeRight.height(localX: 0, localZ: localZ),
                accuracy: 0.0001
            )
        }
    }

    func testTerrainSystemProducesInspectableSampleGridFields() {
        let grid = TerrainSystem(seed: WorldSeed(42)).sampleGrid(for: .origin)
        let sample = grid[12, 34]
        let normalLength = (
            sample.normal.x * sample.normal.x +
                sample.normal.y * sample.normal.y +
                sample.normal.z * sample.normal.z
        ).squareRoot()

        XCTAssertEqual(grid.resolution, ChunkHeightmap.resolution)
        XCTAssertEqual(grid.samples.count, ChunkHeightmap.sampleCount)
        XCTAssertTrue(sample.height.isFinite)
        XCTAssertEqual(normalLength, 1, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(sample.slope, 0)
        XCTAssertGreaterThanOrEqual(sample.curvature, 0)
        XCTAssertGreaterThanOrEqual(sample.roughness, 0)
        XCTAssertLessThanOrEqual(sample.roughness, 1)
        XCTAssertGreaterThanOrEqual(sample.moisture, 0)
        XCTAssertLessThanOrEqual(sample.moisture, 1)
        XCTAssertGreaterThanOrEqual(sample.temperature, 0)
        XCTAssertLessThanOrEqual(sample.temperature, 1)
        XCTAssertTrue(sample.materialWeights.isNormalized)
        XCTAssertGreaterThanOrEqual(sample.walkability, 0)
        XCTAssertLessThanOrEqual(sample.walkability, 1)
        XCTAssertGreaterThanOrEqual(sample.climbability, 0)
        XCTAssertLessThanOrEqual(sample.climbability, 1)
    }

    func testTerrainSystemSharesDerivedFieldsBetweenAdjacentChunks() {
        let terrain = TerrainSystem(seed: WorldSeed(99))
        let left = terrain.sampleGrid(for: .origin)
        let right = terrain.sampleGrid(for: ChunkCoordinate(x: 1, y: 0, z: 0))
        let back = terrain.sampleGrid(for: ChunkCoordinate(x: 0, y: 0, z: 1))

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            let leftSample = left[ChunkHeightmap.resolution - 1, localZ]
            let rightSample = right[0, localZ]

            XCTAssertEqual(leftSample.worldX, rightSample.worldX)
            XCTAssertEqual(leftSample.worldZ, rightSample.worldZ)
            XCTAssertEqual(leftSample.height, rightSample.height, accuracy: 0.0001)
            XCTAssertEqual(leftSample.slope, rightSample.slope, accuracy: 0.0001)
            XCTAssertEqual(leftSample.curvature, rightSample.curvature, accuracy: 0.0001)
            XCTAssertEqual(leftSample.materialWeights, rightSample.materialWeights)
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            let frontSample = left[localX, ChunkHeightmap.resolution - 1]
            let backSample = back[localX, 0]

            XCTAssertEqual(frontSample.worldX, backSample.worldX)
            XCTAssertEqual(frontSample.worldZ, backSample.worldZ)
            XCTAssertEqual(frontSample.height, backSample.height, accuracy: 0.0001)
            XCTAssertEqual(frontSample.slope, backSample.slope, accuracy: 0.0001)
            XCTAssertEqual(frontSample.curvature, backSample.curvature, accuracy: 0.0001)
            XCTAssertEqual(frontSample.materialWeights, backSample.materialWeights)
        }
    }

    func testTerrainSystemDerivesPlaceholderMaterialsFromFields() {
        let terrain = TerrainSystem(seed: WorldSeed(99))
        let coordinates = [
            ChunkCoordinate.origin,
            ChunkCoordinate(x: 2, y: 0, z: -3),
            ChunkCoordinate(x: -4, y: 0, z: 5),
        ]
        let samples = coordinates.flatMap { terrain.sampleGrid(for: $0).samples }
        let derivedMaterialKinds = Set(samples.flatMap { sample in
            sample.materialWeights.splat.layers.map(\.materialKind)
        })

        XCTAssertTrue(derivedMaterialKinds.contains(.rock) || derivedMaterialKinds.contains(.snow))
        XCTAssertTrue(samples.allSatisfy { $0.materialWeights.isNormalized })
    }

    func testTerrainDebugLayersExposeSampleValues() {
        let grid = TerrainSystem(seed: WorldSeed(42)).sampleGrid(for: .origin)
        let layers = TerrainDebugLayers(grid: grid)
        let sample = grid[7, 9]

        XCTAssertEqual(layers.value(for: .altitude, localX: 7, localZ: 9), sample.height, accuracy: 0.0001)
        XCTAssertEqual(layers.value(for: .slope, localX: 7, localZ: 9), sample.slope, accuracy: 0.0001)
        XCTAssertEqual(layers.value(for: .walkability, localX: 7, localZ: 9), sample.walkability, accuracy: 0.0001)
        XCTAssertEqual(layers.values(for: .moisture).count, ChunkHeightmap.sampleCount)
    }

    func testTerrainValidationReportSummarizesGoldenSeeds() {
        let seeds = [WorldSeed(1), WorldSeed(42), WorldSeed(12_345)]

        for seed in seeds {
            let report = TerrainSystem(seed: seed)
                .validationReport(for: ChunkCoordinate(x: 1, y: 0, z: -2))

            XCTAssertTrue(report.isValid)
            XCTAssertLessThanOrEqual(report.minHeight, report.maxHeight)
            XCTAssertGreaterThanOrEqual(report.maxSlope, 0)
            XCTAssertGreaterThanOrEqual(report.walkableRatio, 0)
            XCTAssertLessThanOrEqual(report.walkableRatio, 1)
            XCTAssertGreaterThanOrEqual(report.climbableRatio, 0)
            XCTAssertLessThanOrEqual(report.climbableRatio, 1)
            XCTAssertEqual(
                report.materialCoverage.values.reduce(0, +),
                1,
                accuracy: 0.0001
            )
        }
    }

    func testTerrainSystemVertexMaterialsComeFromSampleGridWeights() {
        let terrain = TerrainSystem(seed: WorldSeed(99))
        let coordinate = ChunkCoordinate(x: -2, y: 0, z: 3)
        let grid = terrain.sampleGrid(for: coordinate)
        let materials = terrain.terrainVertexMaterials(for: coordinate)
        let index = 18 * ChunkHeightmap.resolution + 11

        XCTAssertEqual(materials.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(materials[index].splat, grid[11, 18].materialWeights.splat)
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
            XCTAssertGreaterThanOrEqual(biome.propDensityMultiplier, 0)
            XCTAssertFalse(biome.terrainMaterial.identifier.isEmpty)
            XCTAssertGreaterThanOrEqual(biome.terrainMaterial.roughness, 0)
            XCTAssertLessThanOrEqual(biome.terrainMaterial.roughness, 1)
        }
    }

    func testTerrainMaterialDescriptorsExposeBasicMaterialData() {
        for kind in TerrainMaterialKind.allCases {
            let descriptor = TerrainMaterialDescriptor.definition(for: kind)

            XCTAssertEqual(descriptor.kind, kind)
            XCTAssertFalse(descriptor.identifier.isEmpty)
            XCTAssertGreaterThanOrEqual(descriptor.baseColor.red, 0)
            XCTAssertLessThanOrEqual(descriptor.baseColor.red, 1)
            XCTAssertGreaterThanOrEqual(descriptor.baseColor.green, 0)
            XCTAssertLessThanOrEqual(descriptor.baseColor.green, 1)
            XCTAssertGreaterThanOrEqual(descriptor.baseColor.blue, 0)
            XCTAssertLessThanOrEqual(descriptor.baseColor.blue, 1)
            XCTAssertGreaterThanOrEqual(descriptor.roughness, 0)
            XCTAssertLessThanOrEqual(descriptor.roughness, 1)
        }
    }

    func testTerrainTextureSlotsAreExplicitAndStable() {
        let slots = TerrainTextureSlot.allTerrainSlots

        XCTAssertEqual(slots.count, TerrainMaterialKind.allCases.count)
        XCTAssertEqual(slots.map(\.textureLayerIndex), Array(0..<slots.count))

        for slot in slots {
            let descriptor = TerrainMaterialDescriptor.definition(for: slot.materialKind)

            XCTAssertEqual(slot.map, .albedo)
            XCTAssertEqual(slot.materialIdentifier, descriptor.identifier)
            XCTAssertGreaterThan(slot.uvScale, 0)
            XCTAssertFalse(slot.debugName.isEmpty)
        }

        XCTAssertEqual(TerrainTextureSlot.slot(for: .grass).textureLayerIndex, 0)
        XCTAssertEqual(TerrainTextureSlot.slot(for: .rock).textureLayerIndex, 1)
        XCTAssertEqual(TerrainTextureSlot.slot(for: .wetValley).debugName, "Wet valley")
    }

    func testTerrainPBRTextureSlotsAreAvailableForEachMaterial() {
        let allSlots = TerrainTextureSlot.allTerrainPBRSlots

        XCTAssertEqual(
            allSlots.count,
            TerrainMaterialKind.allCases.count * TerrainTextureMap.allCases.count
        )

        for kind in TerrainMaterialKind.allCases {
            let slots = TerrainTextureSlot.pbrSlots(for: kind)

            XCTAssertEqual(slots.allSlots.map(\.map), TerrainTextureMap.allCases)
            XCTAssertTrue(slots.allSlots.allSatisfy { $0.materialKind == kind })
            XCTAssertTrue(slots.allSlots.allSatisfy {
                $0.textureLayerIndex == TerrainTextureSlot.textureLayerIndex(for: kind)
            })
            XCTAssertTrue(slots.allSlots.allSatisfy {
                $0.uvScale == TerrainTextureSlot.uvScale(for: kind)
            })
        }
    }

    func testRenderMaterialWrapsTerrainTextureSlot() {
        let descriptor = TerrainMaterialDescriptor.definition(for: .rock)
        let material = RenderMaterial.terrain(descriptor)

        guard let slot = material.terrainTextureSlot else {
            XCTFail("Terrain render material should expose a texture slot.")
            return
        }

        XCTAssertEqual(material.identifier, descriptor.identifier)
        XCTAssertEqual(material.baseColor, descriptor.baseColor)
        XCTAssertEqual(material.roughness, descriptor.roughness, accuracy: 0.0001)
        XCTAssertEqual(slot.materialKind, .rock)
        XCTAssertEqual(slot.textureLayerIndex, TerrainTextureSlot.textureLayerIndex(for: .rock))
        XCTAssertEqual(slot.uvScale, TerrainTextureSlot.uvScale(for: .rock), accuracy: 0.0001)

        guard let pbrSlots = material.terrainPBRTextureSlots else {
            XCTFail("Terrain render material should expose PBR texture slots.")
            return
        }

        XCTAssertEqual(pbrSlots.albedo, slot)
        XCTAssertEqual(pbrSlots.normal.map, .normal)
        XCTAssertEqual(pbrSlots.roughness.map, .roughness)
        XCTAssertEqual(pbrSlots.metallicAmbientOcclusion.map, .metallicAmbientOcclusion)
    }

    func testBiomeDefinitionsMapToExpectedTerrainMaterials() {
        XCTAssertEqual(Biome.definition(for: .grassland).terrainMaterial.kind, .grass)
        XCTAssertEqual(Biome.definition(for: .forest).terrainMaterial.kind, .dirt)
        XCTAssertEqual(Biome.definition(for: .rockyHighlands).terrainMaterial.kind, .rock)
        XCTAssertEqual(Biome.definition(for: .dryPlateau).terrainMaterial.kind, .sand)
        XCTAssertEqual(Biome.definition(for: .wetValley).terrainMaterial.kind, .wetValley)
    }

    func testBiomeRuleSetClassifiesClimateSamples() {
        let ruleSet = BiomeRuleSet()

        XCTAssertEqual(
            ruleSet.biomeType(
                for: ClimateSample(
                    elevation: 0.72,
                    moisture: -0.10,
                    temperature: 0.05,
                    continentalness: 0.20
                )
            ),
            .rockyHighlands
        )
        XCTAssertEqual(
            ruleSet.biomeType(
                for: ClimateSample(
                    elevation: -0.42,
                    moisture: 0.35,
                    temperature: 0.10,
                    continentalness: -0.10
                )
            ),
            .wetValley
        )
        XCTAssertEqual(
            ruleSet.biomeType(
                for: ClimateSample(
                    elevation: 0.12,
                    moisture: -0.50,
                    temperature: 0.45,
                    continentalness: 0.24
                )
            ),
            .dryPlateau
        )
        XCTAssertEqual(
            ruleSet.biomeType(
                for: ClimateSample(
                    elevation: 0.05,
                    moisture: 0.28,
                    temperature: 0.12,
                    continentalness: -0.10
                )
            ),
            .forest
        )
        XCTAssertEqual(
            ruleSet.biomeType(
                for: ClimateSample(
                    elevation: 0.02,
                    moisture: -0.05,
                    temperature: 0.05,
                    continentalness: -0.10
                )
            ),
            .grassland
        )
    }

    func testClimateSamplerIsDeterministicForSameSeedAndPosition() {
        let position = WorldPosition(x: -212.5, y: 0, z: 884.25)
        let first = BiomeSampler(seed: WorldSeed(42)).climate(at: position)
        let second = BiomeSampler(seed: WorldSeed(42)).climate(at: position)

        XCTAssertEqual(first, second)
        XCTAssertGreaterThanOrEqual(first.elevation, -1)
        XCTAssertLessThanOrEqual(first.elevation, 1)
        XCTAssertGreaterThanOrEqual(first.moisture, -1)
        XCTAssertLessThanOrEqual(first.moisture, 1)
        XCTAssertGreaterThanOrEqual(first.temperature, -1)
        XCTAssertLessThanOrEqual(first.temperature, 1)
        XCTAssertGreaterThanOrEqual(first.continentalness, -1)
        XCTAssertLessThanOrEqual(first.continentalness, 1)
    }

    func testClimateSamplerChangesAcrossSeeds() {
        let position = WorldPosition(x: -212.5, y: 0, z: 884.25)
        let first = BiomeSampler(seed: WorldSeed(42)).climate(at: position)
        let second = BiomeSampler(seed: WorldSeed(43)).climate(at: position)

        XCTAssertNotEqual(first, second)
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

    func testTerrainVertexMaterialMirrorsSampledBiomeMaterial() {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        let coordinate = ChunkCoordinate(x: -3, y: 0, z: 4)
        let biome = sampler.biome(for: coordinate, localX: 12, localZ: 48)
        let material = sampler.terrainVertexMaterial(for: coordinate, localX: 12, localZ: 48)

        XCTAssertEqual(material.biomeType, biome.type)
        XCTAssertEqual(material.materialKind, biome.terrainMaterial.kind)
        XCTAssertEqual(material.materialIdentifier, biome.terrainMaterial.identifier)
        XCTAssertEqual(material.baseColor, biome.terrainMaterial.baseColor)
        XCTAssertEqual(material.roughness, biome.terrainMaterial.roughness)
    }

    func testTerrainVertexMaterialBlendWeightsAreNormalized() {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        let coordinates = [
            ChunkCoordinate.origin,
            ChunkCoordinate(x: -3, y: 0, z: 4),
            ChunkCoordinate(x: 5, y: 0, z: -2),
        ]

        for coordinate in coordinates {
            for localZ in stride(from: 0, through: ChunkHeightmap.resolution - 1, by: 9) {
                for localX in stride(from: 0, through: ChunkHeightmap.resolution - 1, by: 11) {
                    let material = sampler.terrainVertexMaterial(
                        for: coordinate,
                        localX: localX,
                        localZ: localZ
                    )

                    XCTAssertGreaterThanOrEqual(material.primaryWeight, 0)
                    XCTAssertLessThanOrEqual(material.primaryWeight, 1)
                    XCTAssertGreaterThanOrEqual(material.secondaryWeight, 0)
                    XCTAssertLessThanOrEqual(material.secondaryWeight, 1)
                    XCTAssertEqual(
                        material.primaryWeight + material.secondaryWeight,
                        1,
                        accuracy: 0.0001
                    )

                    if material.blendWeight == 0 {
                        XCTAssertEqual(material.secondaryBiomeType, material.biomeType)
                        XCTAssertEqual(material.secondaryMaterialIdentifier, material.materialIdentifier)
                    }
                }
            }
        }
    }

    func testTerrainVertexMaterialProducesDeterministicSoftTransitions() throws {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        var transitionMaterial: TerrainVertexMaterial?

        for z in stride(from: -512, through: 512, by: 16) {
            for x in stride(from: -512, through: 512, by: 16) {
                let material = sampler.terrainVertexMaterial(at: WorldPosition(
                    x: Float(x),
                    y: 0,
                    z: Float(z)
                ))

                if material.hasBlend {
                    transitionMaterial = material
                    break
                }
            }

            if transitionMaterial != nil {
                break
            }
        }

        let material = try XCTUnwrap(transitionMaterial)
        XCTAssertNotEqual(material.biomeType, material.secondaryBiomeType)
        XCTAssertNotEqual(material.materialIdentifier, material.secondaryMaterialIdentifier)
        XCTAssertGreaterThan(material.blendWeight, 0)
        XCTAssertLessThanOrEqual(material.blendWeight, 0.45)

        let repeatMaterial = sampler.terrainVertexMaterial(at: WorldPosition(
            x: -512,
            y: 0,
            z: -512
        ))
        XCTAssertEqual(
            repeatMaterial,
            sampler.terrainVertexMaterial(at: WorldPosition(x: -512, y: 0, z: -512))
        )
    }

    func testTerrainVertexMaterialBlendsColorAndRoughness() {
        let primary = Biome.definition(for: .grassland)
        let secondary = Biome.definition(for: .rockyHighlands)
        let material = TerrainVertexMaterial(
            primaryBiome: primary,
            secondaryBiome: secondary,
            blendWeight: 0.25
        )
        let blendedColor = material.blendedBaseColor

        XCTAssertEqual(material.primaryWeight, 0.75, accuracy: 0.0001)
        XCTAssertEqual(material.secondaryWeight, 0.25, accuracy: 0.0001)
        XCTAssertEqual(
            blendedColor.red,
            primary.terrainMaterial.baseColor.red * 0.75 + secondary.terrainMaterial.baseColor.red * 0.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            blendedColor.green,
            primary.terrainMaterial.baseColor.green * 0.75 + secondary.terrainMaterial.baseColor.green * 0.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            blendedColor.blue,
            primary.terrainMaterial.baseColor.blue * 0.75 + secondary.terrainMaterial.baseColor.blue * 0.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            material.blendedRoughness,
            primary.terrainMaterial.roughness * 0.75 + secondary.terrainMaterial.roughness * 0.25,
            accuracy: 0.0001
        )
    }

    func testTerrainMaterialSplatNormalizesAndLimitsLayers() {
        let splat = TerrainMaterialSplat(layers: BiomeType.allCases.map { type in
            TerrainMaterialSplatLayer(
                biome: Biome.definition(for: type),
                weight: 1
            )
        })

        XCTAssertEqual(splat.layers.count, TerrainMaterialSplat.maxLayerCount)
        XCTAssertTrue(splat.isNormalized)
        XCTAssertEqual(splat.totalWeight, 1, accuracy: 0.0001)
        XCTAssertTrue(splat.layers.allSatisfy { $0.weight > 0 })
    }

    func testBiomeSamplerTerrainMaterialSplatIsDeterministicAndNormalized() {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        let position = WorldPosition(x: -128, y: 0, z: 288)
        let first = sampler.terrainMaterialSplat(at: position)
        let second = sampler.terrainMaterialSplat(at: position)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.isNormalized)
        XCTAssertGreaterThanOrEqual(first.layers.count, 1)
        XCTAssertLessThanOrEqual(first.layers.count, TerrainMaterialSplat.maxLayerCount)

        for index in 1..<first.layers.count {
            XCTAssertGreaterThanOrEqual(
                first.layers[index - 1].weight + 0.0001,
                first.layers[index].weight
            )
        }
    }

    func testBiomeSamplerTerrainMaterialSplatProducesTransitionLayers() throws {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        var transitionSplat: TerrainMaterialSplat?

        for z in stride(from: -512, through: 512, by: 16) {
            for x in stride(from: -512, through: 512, by: 16) {
                let splat = sampler.terrainMaterialSplat(at: WorldPosition(
                    x: Float(x),
                    y: 0,
                    z: Float(z)
                ))

                if splat.layers.count > 1 {
                    transitionSplat = splat
                    break
                }
            }

            if transitionSplat != nil {
                break
            }
        }

        let splat = try XCTUnwrap(transitionSplat)
        XCTAssertTrue(splat.isNormalized)
        XCTAssertGreaterThan(splat.secondaryWeight, 0)
        XCTAssertLessThanOrEqual(splat.secondaryWeight, 0.45)
    }

    func testTerrainVertexMaterialCarriesSplatWeights() {
        let primary = Biome.definition(for: .grassland)
        let secondary = Biome.definition(for: .forest)
        let tertiary = Biome.definition(for: .dryPlateau)
        let splat = TerrainMaterialSplat(layers: [
            TerrainMaterialSplatLayer(biome: primary, weight: 0.70),
            TerrainMaterialSplatLayer(biome: secondary, weight: 0.20),
            TerrainMaterialSplatLayer(biome: tertiary, weight: 0.10),
        ])
        let material = TerrainVertexMaterial(primaryBiome: primary, splat: splat)

        XCTAssertEqual(material.splat, splat)
        XCTAssertEqual(material.splat.layers.count, 3)
        XCTAssertEqual(material.splat.totalWeight, 1, accuracy: 0.0001)
        XCTAssertEqual(material.secondaryBiomeType, .forest)
        XCTAssertEqual(material.blendWeight, 0.20, accuracy: 0.0001)
    }

    func testTerrainMaterialSplatLayersCarryTextureSlots() {
        let biome = Biome.definition(for: .rockyHighlands)
        let layer = TerrainMaterialSplatLayer(biome: biome, weight: 0.75)

        XCTAssertEqual(layer.renderMaterial.identifier, biome.terrainMaterial.identifier)
        XCTAssertEqual(layer.textureSlot.materialKind, biome.terrainMaterial.kind)
        XCTAssertEqual(
            layer.textureSlot.textureLayerIndex,
            TerrainTextureSlot.textureLayerIndex(for: biome.terrainMaterial.kind)
        )
        XCTAssertEqual(
            layer.textureSlot.uvScale,
            TerrainTextureSlot.uvScale(for: biome.terrainMaterial.kind),
            accuracy: 0.0001
        )
        XCTAssertEqual(layer.pbrTextureSlots.albedo, layer.textureSlot)
        XCTAssertEqual(layer.pbrTextureSlots.normal.map, .normal)
        XCTAssertEqual(layer.pbrTextureSlots.roughness.map, .roughness)
        XCTAssertEqual(layer.pbrTextureSlots.metallicAmbientOcclusion.map, .metallicAmbientOcclusion)
    }

    func testBiomeSamplerSharesTerrainVertexMaterialsBetweenAdjacentChunks() {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        let left = ChunkCoordinate(x: 0, y: 0, z: 0)
        let right = ChunkCoordinate(x: 1, y: 0, z: 0)
        let back = ChunkCoordinate(x: 0, y: 0, z: 1)
        let negativeLeft = ChunkCoordinate(x: -2, y: 0, z: -3)
        let negativeRight = ChunkCoordinate(x: -1, y: 0, z: -3)

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                sampler.terrainVertexMaterial(
                    for: left,
                    localX: ChunkHeightmap.resolution - 1,
                    localZ: localZ
                ),
                sampler.terrainVertexMaterial(
                    for: right,
                    localX: 0,
                    localZ: localZ
                )
            )
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                sampler.terrainVertexMaterial(
                    for: left,
                    localX: localX,
                    localZ: ChunkHeightmap.resolution - 1
                ),
                sampler.terrainVertexMaterial(
                    for: back,
                    localX: localX,
                    localZ: 0
                )
            )
        }

        for localZ in [0, 29, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                sampler.terrainVertexMaterial(
                    for: negativeLeft,
                    localX: ChunkHeightmap.resolution - 1,
                    localZ: localZ
                ),
                sampler.terrainVertexMaterial(
                    for: negativeRight,
                    localX: 0,
                    localZ: localZ
                )
            )
        }
    }

    func testBiomeSamplerSharesTerrainMaterialSplatsBetweenAdjacentChunks() {
        let sampler = BiomeSampler(seed: WorldSeed(99))
        let left = ChunkCoordinate(x: 0, y: 0, z: 0)
        let right = ChunkCoordinate(x: 1, y: 0, z: 0)
        let back = ChunkCoordinate(x: 0, y: 0, z: 1)
        let negativeLeft = ChunkCoordinate(x: -2, y: 0, z: -3)
        let negativeRight = ChunkCoordinate(x: -1, y: 0, z: -3)

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                sampler.terrainMaterialSplat(
                    for: left,
                    localX: ChunkHeightmap.resolution - 1,
                    localZ: localZ
                ),
                sampler.terrainMaterialSplat(
                    for: right,
                    localX: 0,
                    localZ: localZ
                )
            )
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                sampler.terrainMaterialSplat(
                    for: left,
                    localX: localX,
                    localZ: ChunkHeightmap.resolution - 1
                ),
                sampler.terrainMaterialSplat(
                    for: back,
                    localX: localX,
                    localZ: 0
                )
            )
        }

        for localZ in [0, 29, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                sampler.terrainMaterialSplat(
                    for: negativeLeft,
                    localX: ChunkHeightmap.resolution - 1,
                    localZ: localZ
                ),
                sampler.terrainMaterialSplat(
                    for: negativeRight,
                    localX: 0,
                    localZ: localZ
                )
            )
        }
    }

    func testPropPlacementGeneratorIsDeterministicForSameSeedAndChunk() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let biome = Biome.definition(for: .forest)
        let first = PropPlacementGenerator(seed: WorldSeed(42)).placements(for: coordinate, biome: biome)
        let second = PropPlacementGenerator(seed: WorldSeed(42)).placements(for: coordinate, biome: biome)

        XCTAssertEqual(first, second)
    }

    func testPropPlacementGeneratorAssignsStablePlacementIndexes() {
        let props = PropPlacementGenerator(seed: WorldSeed(42)).placements(
            for: .origin,
            biome: Biome.definition(for: .forest)
        )

        XCTAssertEqual(props.map(\.placementIndex), Array(0..<props.count))
    }

    func testPropPlacementGeneratorDiffersForDifferentChunks() {
        let generator = PropPlacementGenerator(seed: WorldSeed(42))
        let biome = Biome.definition(for: .rockyHighlands)
        let first = generator.placements(for: ChunkCoordinate(x: 0, y: 0, z: 0), biome: biome)
        let second = generator.placements(for: ChunkCoordinate(x: 1, y: 0, z: 0), biome: biome)

        XCTAssertNotEqual(first, second)
    }

    func testPropPlacementGeneratorDiffersForDifferentSeeds() {
        let coordinate = ChunkCoordinate(x: -1, y: 0, z: 2)
        let biome = Biome.definition(for: .dryPlateau)
        let first = PropPlacementGenerator(seed: WorldSeed(1)).placements(for: coordinate, biome: biome)
        let second = PropPlacementGenerator(seed: WorldSeed(2)).placements(for: coordinate, biome: biome)

        XCTAssertNotEqual(first, second)
    }

    func testPropPlacementGeneratorHonorsMaxPropsPerChunk() {
        let generator = PropPlacementGenerator(seed: WorldSeed(42), maxPropsPerChunk: 3)
        let props = generator.placements(for: .origin, biome: Biome.definition(for: .forest))

        XCTAssertEqual(props.count, 3)
    }

    func testPropPlacementDensityIsInfluencedByBiome() {
        let generator = PropPlacementGenerator(seed: WorldSeed(42), maxPropsPerChunk: 64)
        let coordinate = ChunkCoordinate(x: 0, y: 0, z: 0)
        let plainProps = generator.placements(for: coordinate, biome: Biome.definition(for: .grassland))
        let forestProps = generator.placements(for: coordinate, biome: Biome.definition(for: .forest))

        XCTAssertGreaterThan(forestProps.count, plainProps.count)
    }

    func testPropPlacementsStayInsideChunk() {
        let generator = PropPlacementGenerator(seed: WorldSeed(42))
        let props = generator.placements(
            for: ChunkCoordinate(x: -2, y: 0, z: 3),
            biome: Biome.definition(for: .rockyHighlands)
        )
        let maxLocalPosition = Float(ChunkHeightmap.resolution - 1)

        XCTAssertFalse(props.isEmpty)

        for prop in props {
            XCTAssertGreaterThanOrEqual(prop.localX, 0)
            XCTAssertLessThanOrEqual(prop.localX, maxLocalPosition)
            XCTAssertGreaterThanOrEqual(prop.localZ, 0)
            XCTAssertLessThanOrEqual(prop.localZ, maxLocalPosition)
            XCTAssertTrue(prop.rotationRadians.isFinite)
            XCTAssertGreaterThan(prop.scale, 0)
        }
    }

    func testProceduralAssetGeneratorIsDeterministicForSameSeedAndPlacement() {
        let placement = samplePropPlacement(type: .treePlaceholder)
        let biome = Biome.definition(for: .forest)
        let chunk = ChunkCoordinate(x: 2, y: 0, z: -3)
        let generator = ProceduralAssetGenerator(seed: WorldSeed(42))
        let first = generator.variant(for: placement, biome: biome, chunk: chunk)
        let second = generator.variant(for: placement, biome: biome, chunk: chunk)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.placement, placement)
        XCTAssertFalse(first.geometry.parts.isEmpty)
    }

    func testProceduralAssetGeneratorChangesAcrossSeeds() {
        let placement = samplePropPlacement(type: .rock)
        let biome = Biome.definition(for: .rockyHighlands)
        let chunk = ChunkCoordinate(x: 2, y: 0, z: -3)
        let first = ProceduralAssetGenerator(seed: WorldSeed(42)).variant(
            for: placement,
            biome: biome,
            chunk: chunk
        )
        let second = ProceduralAssetGenerator(seed: WorldSeed(43)).variant(
            for: placement,
            biome: biome,
            chunk: chunk
        )

        XCTAssertNotEqual(first.variantSeed, second.variantSeed)
        XCTAssertNotEqual(first, second)
    }

    func testProceduralAssetGeneratorChangesAcrossBiomes() {
        let placement = samplePropPlacement(type: .treePlaceholder)
        let chunk = ChunkCoordinate(x: 0, y: 0, z: 0)
        let generator = ProceduralAssetGenerator(seed: WorldSeed(42))
        let forest = generator.variant(
            for: placement,
            biome: Biome.definition(for: .forest),
            chunk: chunk
        )
        let dryPlateau = generator.variant(
            for: placement,
            biome: Biome.definition(for: .dryPlateau),
            chunk: chunk
        )

        XCTAssertNotEqual(forest.variantSeed, dryPlateau.variantSeed)
        XCTAssertNotEqual(forest.archetypeID, dryPlateau.archetypeID)
        XCTAssertNotEqual(forest.secondaryMaterial, dryPlateau.secondaryMaterial)
    }

    func testProceduralAssetGeneratorProducesGeometryWithMaterialSlots() {
        let placement = samplePropPlacement(type: .crystalPlaceholder)
        let variant = ProceduralAssetGenerator(seed: WorldSeed(42)).variant(
            for: placement,
            biome: Biome.definition(for: .wetValley),
            chunk: .origin
        )
        let slots = Set(variant.geometry.parts.map(\.materialSlot))

        XCTAssertTrue(slots.contains(.primary))
        XCTAssertTrue(slots.contains(.accent))
        XCTAssertGreaterThan(variant.collisionSize.x, 0)
        XCTAssertGreaterThan(variant.collisionSize.y, 0)
        XCTAssertGreaterThan(variant.collisionSize.z, 0)
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

    func testTerrainSamplerReportsWalkabilityFromSlope() {
        let flatSampler = TerrainSampler(geometry: flatGeometry(height: 3, horizontalScale: 1))
        let rampSampler = TerrainSampler(geometry: rampGeometry(horizontalScale: 1, verticalScale: 1))
        let rampSample = rampSampler.sampleAt(x: 20, z: 20)

        XCTAssertTrue(flatSampler.isWalkableAt(x: 20, z: 20, maxSlope: 0))
        XCTAssertFalse(rampSample.isWalkable(maxSlope: 1))
        XCTAssertTrue(rampSample.isWalkable(maxSlope: 5))
    }

    func testTerrainGeometrySharesBorderHeightsBetweenAdjacentChunks() {
        let left = ChunkCoordinate.origin.makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let right = ChunkCoordinate(x: 1, y: 0, z: 0).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let back = ChunkCoordinate(x: 0, y: 0, z: 1).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let negativeLeft = ChunkCoordinate(x: -2, y: 0, z: -3).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let negativeRight = ChunkCoordinate(x: -1, y: 0, z: -3).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                terrainGeometryHeight(left, localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                terrainGeometryHeight(right, localX: 0, localZ: localZ),
                accuracy: 0.0001
            )
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                terrainGeometryHeight(left, localX: localX, localZ: ChunkHeightmap.resolution - 1),
                terrainGeometryHeight(back, localX: localX, localZ: 0),
                accuracy: 0.0001
            )
        }

        for localZ in [0, 29, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                terrainGeometryHeight(negativeLeft, localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                terrainGeometryHeight(negativeRight, localX: 0, localZ: localZ),
                accuracy: 0.0001
            )
        }
    }

    func testTerrainGeometrySharesBorderNormalsBetweenAdjacentChunks() {
        let left = ChunkCoordinate.origin.makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let right = ChunkCoordinate(x: 1, y: 0, z: 0).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let back = ChunkCoordinate(x: 0, y: 0, z: 1).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let negativeLeft = ChunkCoordinate(x: -2, y: 0, z: -3).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )
        let negativeRight = ChunkCoordinate(x: -1, y: 0, z: -3).makeTerrainGeometry(
            seed: WorldSeed(99),
            horizontalScale: 1,
            verticalScale: 1
        )

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            assertNormalsEqual(
                terrainGeometryNormal(left, localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                terrainGeometryNormal(right, localX: 0, localZ: localZ)
            )
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            assertNormalsEqual(
                terrainGeometryNormal(left, localX: localX, localZ: ChunkHeightmap.resolution - 1),
                terrainGeometryNormal(back, localX: localX, localZ: 0)
            )
        }

        for localZ in [0, 29, ChunkHeightmap.resolution - 1] {
            assertNormalsEqual(
                terrainGeometryNormal(negativeLeft, localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                terrainGeometryNormal(negativeRight, localX: 0, localZ: localZ)
            )
        }
    }

    func testRenderWorldSnapshotCountsVisibleRenderData() {
        let propVariant = ProceduralAssetGenerator(seed: WorldSeed(77)).variant(
            for: samplePropPlacement(type: .rock),
            biome: Biome.definition(for: .rockyHighlands),
            chunk: .origin
        )
        let visibleChunk = sampleRenderChunk(
            coordinate: .origin,
            props: [
                RenderProp(
                    variant: propVariant,
                    worldPosition: WorldPosition(x: 1, y: 2, z: 3),
                    rotationRadians: 0.5
                )
            ],
            isVisible: true,
            approximateTriangleCount: 128
        )
        let hiddenChunk = sampleRenderChunk(
            coordinate: ChunkCoordinate(x: 1, y: 0, z: 0),
            props: [
                RenderProp(
                    variant: propVariant,
                    worldPosition: WorldPosition(x: 4, y: 5, z: 6),
                    rotationRadians: 0.2
                )
            ],
            isVisible: false,
            approximateTriangleCount: 256
        )
        let snapshot = RenderWorldSnapshot(
            camera: sampleCameraRenderState(),
            chunks: [visibleChunk, hiddenChunk],
            debugOptions: RenderDebugOptions(
                showChunkBounds: true,
                showChunkLabels: true,
                terrainMaterialDebugMode: .blendWeight,
                terrainSplatDebugLayerIndex: 2
            )
        )

        XCTAssertEqual(snapshot.visibleChunkCount, 1)
        XCTAssertEqual(snapshot.visiblePropCount, 1)
        XCTAssertEqual(snapshot.approximateTriangleCount, 128)
        XCTAssertTrue(snapshot.debugOptions.showChunkBounds)
        XCTAssertTrue(snapshot.debugOptions.showChunkLabels)
        XCTAssertEqual(snapshot.debugOptions.terrainMaterialDebugMode, .blendWeight)
        XCTAssertEqual(snapshot.debugOptions.terrainSplatDebugLayerIndex, 2)
    }

    func testRenderDebugOptionsDefaultToNormalTerrainMaterialMode() {
        let options = RenderDebugOptions()

        XCTAssertFalse(options.showChunkBounds)
        XCTAssertFalse(options.showChunkLabels)
        XCTAssertEqual(options.terrainMaterialDebugMode, .normal)
        XCTAssertEqual(options.terrainSplatDebugLayerIndex, 0)
        XCTAssertEqual(
            TerrainMaterialDebugMode.allCases.map(\.rawValue),
            ["normal", "primaryBiome", "secondaryBiome", "blendWeight", "splatLayerWeight"]
        )
    }

    func testRenderDebugOptionsClampSplatLayerIndex() {
        XCTAssertEqual(
            RenderDebugOptions(terrainSplatDebugLayerIndex: -1).terrainSplatDebugLayerIndex,
            0
        )
        XCTAssertEqual(
            RenderDebugOptions(terrainSplatDebugLayerIndex: 2).terrainSplatDebugLayerIndex,
            2
        )
        XCTAssertEqual(
            RenderDebugOptions(terrainSplatDebugLayerIndex: 99).terrainSplatDebugLayerIndex,
            TerrainMaterialSplat.maxLayerCount - 1
        )
    }

    func testRenderContractsRoundTripThroughJSON() throws {
        let snapshot = RenderWorldSnapshot(
            camera: sampleCameraRenderState(),
            chunks: [
                sampleRenderChunk(
                    coordinate: ChunkCoordinate(x: -1, y: 0, z: 2),
                    props: [],
                    isVisible: true,
                    approximateTriangleCount: 64
                )
            ],
            debugOptions: RenderDebugOptions(
                showChunkBounds: true,
                showChunkLabels: false,
                terrainMaterialDebugMode: .splatLayerWeight,
                terrainSplatDebugLayerIndex: 3
            )
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RenderWorldSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.chunks.first?.debugBounds?.state, .current)
        XCTAssertEqual(decoded.debugOptions.terrainMaterialDebugMode, .splatLayerWeight)
        XCTAssertEqual(decoded.debugOptions.terrainSplatDebugLayerIndex, 3)
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

    private func terrainGeometryHeight(
        _ geometry: TerrainGeometryBuffers,
        localX: Int,
        localZ: Int
    ) -> Float {
        geometry.positions[localZ * geometry.resolution + localX].y
    }

    private func terrainGeometryNormal(
        _ geometry: TerrainGeometryBuffers,
        localX: Int,
        localZ: Int
    ) -> TerrainGeometryBuffers.Normal {
        geometry.normals[localZ * geometry.resolution + localX]
    }

    private func assertNormalsEqual(
        _ first: TerrainGeometryBuffers.Normal,
        _ second: TerrainGeometryBuffers.Normal,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(first.x, second.x, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(first.y, second.y, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(first.z, second.z, accuracy: 0.0001, file: file, line: line)
    }

    private func samplePropPlacement(type: PropType) -> PropPlacement {
        PropPlacement(
            placementIndex: 7,
            type: type,
            localX: 12.5,
            localZ: 24.25,
            worldX: 75.5,
            worldZ: -18.25,
            rotationRadians: 0.42,
            scale: 1.1
        )
    }

    private func sampleCameraRenderState() -> CameraRenderState {
        CameraRenderState(
            position: WorldPosition(x: 2, y: 8, z: 10),
            target: WorldPosition(x: 0, y: 0, z: 0),
            fieldOfViewDegrees: 35,
            yaw: 0.75,
            pitch: 0.55,
            distance: 9
        )
    }

    private func sampleRenderChunk(
        coordinate: ChunkCoordinate,
        props: [RenderProp],
        isVisible: Bool,
        approximateTriangleCount: Int
    ) -> RenderChunk {
        let biome = Biome.definition(for: .grassland)

        return RenderChunk(
            coordinate: coordinate,
            origin: WorldPosition(
                x: Float(coordinate.x) * 16,
                y: 0,
                z: Float(coordinate.z) * 16
            ),
            terrainGeometry: flatGeometry(height: 0, horizontalScale: 1),
            biome: biome,
            terrainMaterial: biome.terrainMaterial,
            props: props,
            debugBounds: RenderChunkDebugBounds(
                coordinate: coordinate,
                origin: WorldPosition(
                    x: Float(coordinate.x) * 16,
                    y: 0,
                    z: Float(coordinate.z) * 16
                ),
                size: PropVector3(x: 16, y: 4, z: 16),
                state: .current
            ),
            isVisible: isVisible,
            approximateTriangleCount: approximateTriangleCount
        )
    }

    private func biomeTypes(
        sampler: BiomeSampler,
        positions: [WorldPosition]
    ) -> Set<BiomeType> {
        Set(positions.map { sampler.biome(at: $0).type })
    }
}
