import XCTest
@testable import EngineCore

final class TerrainFeatureGraphTests: XCTestCase {
    func testTerrainFeatureGraphBuildsV1FeatureFamilies() {
        let graph = TerrainFeatureGraph.make(seed: GoldenWorldSeeds.river)

        XCTAssertEqual(graph.rivers.count, 2)
        XCTAssertEqual(graph.lakes.count, 2)
        XCTAssertEqual(graph.mountainRanges.count, 2)
        XCTAssertEqual(graph.cliffBands.count, 2)
        XCTAssertEqual(graph.featureCount, 8)
        XCTAssertEqual(Set(graph.rivers.map(\.id)).count, graph.rivers.count)
    }

    func testTerrainFeatureGraphIsDeterministicForSameSeed() {
        let first = TerrainFeatureGraph.make(seed: GoldenWorldSeeds.river)
        let second = TerrainFeatureGraph.make(seed: GoldenWorldSeeds.river)
        let other = TerrainFeatureGraph.make(seed: GoldenWorldSeeds.mountains)

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, other)
    }

    func testFeatureGraphQueriesFeaturesByChunk() {
        let terrain = TerrainSystem(seed: GoldenWorldSeeds.river)
        let originQuery = terrain.features(intersecting: .origin)
        let remoteQuery = terrain.features(intersecting: ChunkCoordinate(x: 50, y: 0, z: 50))

        XCTAssertFalse(originQuery.rivers.isEmpty)
        XCTAssertGreaterThan(originQuery.featureCount, 0)
        XCTAssertTrue(remoteQuery.isEmpty)
    }

    func testRiverFeatureCarvesChannelAndExposesWaterAndShoreMasks() {
        let river = RiverFeature(
            id: 1,
            startX: -20,
            startZ: 0,
            endX: 20,
            endZ: 0,
            width: 4,
            shoreWidth: 4,
            carveDepth: 2,
            waterDepth: 0.5
        )

        let center = river.contribution(at: TerrainFeaturePoint(worldX: 0, worldZ: 0))
        let shore = river.contribution(at: TerrainFeaturePoint(worldX: 0, worldZ: 5))
        let far = river.contribution(at: TerrainFeaturePoint(worldX: 0, worldZ: 20))

        XCTAssertLessThan(center.heightOffset, -1.9)
        XCTAssertGreaterThan(center.masks.water, 0.9)
        XCTAssertGreaterThan(center.waterDepth, 0.45)
        XCTAssertGreaterThan(shore.masks.shore, 0.1)
        XCTAssertEqual(far, .zero)
    }

    func testTerrainSystemAppliesHydrologyMasksAndShoreMaterials() {
        let grid = TerrainSystem(seed: GoldenWorldSeeds.river).sampleGrid(for: .origin)
        let waterSamples = grid.samples.filter { $0.featureMasks.water > 0.2 }
        let shoreSamples = grid.samples.filter { $0.featureMasks.shore > 0.1 }
        let waterMaterialKinds = Set(waterSamples.flatMap { sample in
            sample.materialWeights.splat.layers.map(\.materialKind)
        })
        let shoreMaterialKinds = Set(shoreSamples.flatMap { sample in
            sample.materialWeights.splat.layers.map(\.materialKind)
        })

        XCTAssertFalse(waterSamples.isEmpty)
        XCTAssertFalse(shoreSamples.isEmpty)
        XCTAssertTrue(waterSamples.contains { $0.waterDepth > 0 })
        XCTAssertTrue(waterSamples.allSatisfy { (0...1).contains($0.featureMasks.water) })
        XCTAssertTrue(shoreSamples.allSatisfy { (0...1).contains($0.featureMasks.shore) })
        XCTAssertTrue(waterMaterialKinds.contains(.mud))
        XCTAssertTrue(shoreMaterialKinds.contains(.sand) || shoreMaterialKinds.contains(.mud))
    }

    func testHydrologyAndFeatureMasksStayContinuousAcrossChunkBorders() {
        let terrain = TerrainSystem(seed: GoldenWorldSeeds.river)
        let left = terrain.sampleGrid(for: .origin)
        let right = terrain.sampleGrid(for: ChunkCoordinate(x: 1, y: 0, z: 0))
        let back = terrain.sampleGrid(for: ChunkCoordinate(x: 0, y: 0, z: 1))

        for localZ in [0, 17, ChunkHeightmap.resolution - 1] {
            let leftSample = left[ChunkHeightmap.resolution - 1, localZ]
            let rightSample = right[0, localZ]

            XCTAssertEqual(leftSample.waterDepth, rightSample.waterDepth, accuracy: 0.0001)
            XCTAssertEqual(leftSample.featureMasks.water, rightSample.featureMasks.water, accuracy: 0.0001)
            XCTAssertEqual(leftSample.featureMasks.shore, rightSample.featureMasks.shore, accuracy: 0.0001)
            XCTAssertEqual(leftSample.featureMasks.mountain, rightSample.featureMasks.mountain, accuracy: 0.0001)
            XCTAssertEqual(leftSample.featureMasks.cliff, rightSample.featureMasks.cliff, accuracy: 0.0001)
        }

        for localX in [0, 23, ChunkHeightmap.resolution - 1] {
            let frontSample = left[localX, ChunkHeightmap.resolution - 1]
            let backSample = back[localX, 0]

            XCTAssertEqual(frontSample.waterDepth, backSample.waterDepth, accuracy: 0.0001)
            XCTAssertEqual(frontSample.featureMasks.water, backSample.featureMasks.water, accuracy: 0.0001)
            XCTAssertEqual(frontSample.featureMasks.shore, backSample.featureMasks.shore, accuracy: 0.0001)
            XCTAssertEqual(frontSample.featureMasks.mountain, backSample.featureMasks.mountain, accuracy: 0.0001)
            XCTAssertEqual(frontSample.featureMasks.cliff, backSample.featureMasks.cliff, accuracy: 0.0001)
        }
    }

    func testTerrainValidationReportsWaterAndShoreCoverage() {
        let report = TerrainSystem(seed: GoldenWorldSeeds.river).validationReport(for: .origin)

        XCTAssertTrue(report.isValid)
        XCTAssertGreaterThan(report.waterCoverage + report.shoreCoverage, 0)
        XCTAssertGreaterThanOrEqual(report.waterCoverage, 0)
        XCTAssertLessThanOrEqual(report.waterCoverage, 1)
        XCTAssertGreaterThanOrEqual(report.shoreCoverage, 0)
        XCTAssertLessThanOrEqual(report.shoreCoverage, 1)
    }

    func testTerrainDebugLayersExposeFeatureMasks() {
        let grid = TerrainSystem(seed: GoldenWorldSeeds.river).sampleGrid(for: .origin)
        let layers = TerrainDebugLayers(grid: grid)
        let sample = grid[12, 12]

        XCTAssertEqual(layers.value(for: .waterMask, localX: 12, localZ: 12), sample.featureMasks.water, accuracy: 0.0001)
        XCTAssertEqual(layers.value(for: .shoreMask, localX: 12, localZ: 12), sample.featureMasks.shore, accuracy: 0.0001)
        XCTAssertEqual(layers.values(for: .cliffMask).count, ChunkHeightmap.sampleCount)
    }
}
