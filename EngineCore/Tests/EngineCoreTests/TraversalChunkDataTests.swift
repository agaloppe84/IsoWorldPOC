import simd
import XCTest
@testable import EngineCore

final class TraversalChunkDataTests: XCTestCase {
    func testTraversalSurfaceClassificationCoversV1Classes() {
        XCTAssertEqual(
            TraversalSurfaceClass.classify(sample(slope: 0.10, walkability: 0.92)),
            .walkable
        )
        XCTAssertEqual(
            TraversalSurfaceClass.classify(sample(slope: 0.76, walkability: 0.35, climbability: 0.12)),
            .steep
        )
        XCTAssertEqual(
            TraversalSurfaceClass.classify(sample(slope: 1.35, walkability: 0.18, climbability: 0.62)),
            .climbable
        )
        XCTAssertEqual(
            TraversalSurfaceClass.classify(sample(slope: 5.0, walkability: 0.04, climbability: 0.02)),
            .dangerous
        )
        XCTAssertEqual(
            TraversalSurfaceClass.classify(sample(waterDepth: 0.50, featureMasks: TerrainFeatureMasks(water: 1))),
            .blocked
        )
    }

    func testTraversalChunkDataBuildsVerticalCandidatesFromCliffGrid() {
        let traversal = TraversalChunkData(sampleGrid: cliffGrid())

        XCTAssertGreaterThan(traversal.walkableRatio, 0)
        XCTAssertGreaterThan(traversal.climbableRatio, 0)
        XCTAssertFalse(traversal.ledges.isEmpty)
        XCTAssertFalse(traversal.ropeAnchors.isEmpty)
        XCTAssertFalse(traversal.stairAttachCandidates.isEmpty)
        XCTAssertTrue(traversal.verticalTraversalCandidates.contains { $0.kind == .rope })
        XCTAssertTrue(traversal.verticalTraversalCandidates.contains { $0.kind == .carvedStairs })
        XCTAssertTrue(traversal.ledges.allSatisfy { (0...1).contains($0.ledgeScore) })
        XCTAssertTrue(traversal.ropeAnchors.allSatisfy { $0.verticalDistance > 0 })
    }

    func testTraversalChunkDataIsDeterministicForSameGrid() {
        let first = TraversalChunkData(sampleGrid: cliffGrid())
        let second = TraversalChunkData(sampleGrid: cliffGrid())

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.verticalTraversalCandidates.map(\.id), second.verticalTraversalCandidates.map(\.id))
    }

    func testTerrainSystemExposesTraversalData() {
        let terrain = TerrainSystem(seed: GoldenWorldSeeds.river)
        let traversal = terrain.traversalData(for: .origin)

        XCTAssertEqual(traversal.seed, GoldenWorldSeeds.river)
        XCTAssertEqual(traversal.coordinate, .origin)
        XCTAssertEqual(traversal.resolution, ChunkHeightmap.resolution)
        XCTAssertEqual(traversal.climbabilityMap.surfaceClasses.count, ChunkHeightmap.sampleCount)
        XCTAssertGreaterThan(traversal.walkableRatio, 0)
    }

    func testTraversalSurfaceClassesStayContinuousAcrossChunkBorders() {
        let terrain = TerrainSystem(seed: GoldenWorldSeeds.river)
        let left = terrain.traversalData(for: .origin)
        let right = terrain.traversalData(for: ChunkCoordinate(x: 1, y: 0, z: 0))

        for localZ in [0, 11, ChunkHeightmap.resolution - 1] {
            XCTAssertEqual(
                left.surfaceClass(localX: ChunkHeightmap.resolution - 1, localZ: localZ),
                right.surfaceClass(localX: 0, localZ: localZ)
            )
        }
    }

    func testTerrainDebugLayersExposeTraversalValues() {
        let grid = cliffGrid()
        let layers = TerrainDebugLayers(grid: grid)
        let ledge = layers.value(for: .ledgeScore, localX: 2, localZ: 2)
        let surface = layers.value(for: .traversalSurface, localX: 2, localZ: 2)

        XCTAssertGreaterThan(ledge, 0.48)
        XCTAssertEqual(surface, TraversalSurfaceClass.climbable.debugValue, accuracy: 0.0001)
        XCTAssertEqual(layers.values(for: .traversalSurface).count, grid.samples.count)
    }

    func testTerrainValidationReportIncludesTraversalSummary() {
        let report = cliffGrid().validationReport

        XCTAssertTrue(report.isValid)
        XCTAssertGreaterThan(report.traversalCandidateCount, 0)
        XCTAssertGreaterThanOrEqual(report.blockedTraversalRatio, 0)
        XCTAssertLessThanOrEqual(report.blockedTraversalRatio, 1)
    }

    private func cliffGrid() -> TerrainSampleGrid {
        let resolution = 5
        var samples: [TerrainSample] = []
        samples.reserveCapacity(resolution * resolution)

        for localZ in 0..<resolution {
            for localX in 0..<resolution {
                let isCliffFace = localX == 2
                let isTopOrBottom = localX != 2
                let height: Float = localX < 2 ? 2.0 : (isCliffFace ? 1.0 : 0.0)
                let slope: Float = isCliffFace ? 1.35 : 0.12
                let walkability: Float = isTopOrBottom ? 0.92 : 0.20

                samples.append(sample(
                    localX: localX,
                    localZ: localZ,
                    worldX: localX,
                    worldZ: localZ,
                    height: height,
                    slope: slope,
                    curvature: isCliffFace ? 1.20 : 0.10,
                    roughness: isCliffFace ? 0.28 : 0.10,
                    featureMasks: TerrainFeatureMasks(cliff: isCliffFace ? 1 : 0),
                    walkability: walkability,
                    climbability: isCliffFace ? 0.72 : 0.08
                ))
            }
        }

        return TerrainSampleGrid(
            seed: GoldenWorldSeeds.mountains,
            coordinate: .origin,
            resolution: resolution,
            samples: samples
        )
    }

    private func sample(
        localX: Int = 0,
        localZ: Int = 0,
        worldX: Int = 0,
        worldZ: Int = 0,
        height: Float = 0,
        slope: Float = 0,
        curvature: Float = 0,
        roughness: Float = 0,
        waterDepth: Float = 0,
        featureMasks: TerrainFeatureMasks = .zero,
        walkability: Float = 1,
        climbability: Float = 0
    ) -> TerrainSample {
        TerrainSample(
            localX: localX,
            localZ: localZ,
            worldX: worldX,
            worldZ: worldZ,
            height: height,
            normal: SIMD3<Float>(0, 1, 0),
            slope: slope,
            curvature: curvature,
            roughness: roughness,
            materialWeights: .grassland,
            waterDepth: waterDepth,
            featureMasks: featureMasks,
            walkability: walkability,
            climbability: climbability
        )
    }
}
