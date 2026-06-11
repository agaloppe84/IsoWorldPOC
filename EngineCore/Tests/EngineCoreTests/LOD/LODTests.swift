import XCTest
@testable import EngineCore

final class LODTests: XCTestCase {
    func testLODPolicySelectsLevelsByDistance() {
        let policy = LODPolicy(
            thresholds: LODPolicy.DistanceThresholds(
                lod0MaxDistance: 10,
                lod1MaxDistance: 20,
                lod2MaxDistance: 30,
                visibleMaxDistance: 40
            ),
            hysteresis: Hysteresis(distanceMargin: 0),
            budget: LODBudget(maxVisibleChunks: 8),
            chunkWorldExtent: 8,
            viewportHeightPixels: 900
        )

        XCTAssertEqual(LODSelection.select(distance: 5, fieldOfViewDegrees: 35, policy: policy).level, .lod0)
        XCTAssertEqual(LODSelection.select(distance: 15, fieldOfViewDegrees: 35, policy: policy).level, .lod1)
        XCTAssertEqual(LODSelection.select(distance: 25, fieldOfViewDegrees: 35, policy: policy).level, .lod2)
        XCTAssertEqual(LODSelection.select(distance: 35, fieldOfViewDegrees: 35, policy: policy).level, .lod3)
        XCTAssertFalse(LODSelection.select(distance: 45, fieldOfViewDegrees: 35, policy: policy).isVisible)
    }

    func testLODSelectionUsesHysteresisAroundThresholds() {
        let policy = LODPolicy(
            thresholds: LODPolicy.DistanceThresholds(
                lod0MaxDistance: 10,
                lod1MaxDistance: 20,
                lod2MaxDistance: 30,
                visibleMaxDistance: 40
            ),
            hysteresis: Hysteresis(distanceMargin: 2),
            budget: LODBudget(maxVisibleChunks: 8),
            chunkWorldExtent: 8,
            viewportHeightPixels: 900
        )

        let staysNear = LODSelection.select(
            distance: 11,
            fieldOfViewDegrees: 35,
            policy: policy,
            previousLevel: .lod0
        )
        let staysMid = LODSelection.select(
            distance: 9,
            fieldOfViewDegrees: 35,
            policy: policy,
            previousLevel: .lod1
        )

        XCTAssertEqual(staysNear.level, .lod0)
        XCTAssertEqual(staysMid.level, .lod1)
    }

    func testScreenErrorShrinksWithDistance() {
        let near = ScreenError.estimateProjectedPixels(
            worldExtent: 8,
            distance: 8,
            fieldOfViewDegrees: 35,
            viewportHeightPixels: 900
        )
        let far = ScreenError.estimateProjectedPixels(
            worldExtent: 8,
            distance: 32,
            fieldOfViewDegrees: 35,
            viewportHeightPixels: 900
        )

        XCTAssertGreaterThan(near.projectedPixels, far.projectedPixels)
    }

    func testLODFrameStatsCountsVisibleCulledAndLevels() {
        let selections = [
            LODSelection(
                level: .lod0,
                distance: 1,
                screenError: ScreenError(projectedPixels: 100),
                isVisible: true,
                cullingReason: .visible
            ),
            LODSelection(
                level: .lod1,
                distance: 2,
                screenError: ScreenError(projectedPixels: 50),
                isVisible: true,
                cullingReason: .visible
            ),
            LODSelection(
                level: .lod2,
                distance: 3,
                screenError: ScreenError(projectedPixels: 25),
                isVisible: false,
                cullingReason: .budget
            ),
        ]

        let stats = LODFrameStats(selections: selections)

        XCTAssertEqual(stats.candidateChunkCount, 3)
        XCTAssertEqual(stats.visibleChunkCount, 2)
        XCTAssertEqual(stats.culledChunkCount, 1)
        XCTAssertEqual(stats.lod0ChunkCount, 1)
        XCTAssertEqual(stats.lod1ChunkCount, 1)
        XCTAssertEqual(stats.lod2ChunkCount, 0)
        XCTAssertEqual(stats.lod3ChunkCount, 0)
    }

    func testLODSelectionCanDisablePropsWithoutChangingTerrainLevel() {
        let selection = LODSelection(
            level: .lod1,
            distance: 12,
            screenError: ScreenError(projectedPixels: 80),
            isVisible: true,
            cullingReason: .visible
        )

        let withoutProps = selection.withoutProps()

        XCTAssertEqual(withoutProps.level, .lod1)
        XCTAssertTrue(withoutProps.isVisible)
        XCTAssertTrue(selection.rendersProps)
        XCTAssertFalse(withoutProps.rendersProps)
    }

    func testTerrainLODIndicesReduceInteriorWhilePreservingChunkEdges() {
        let geometry = TerrainGeometryBuffers(
            resolution: 5,
            positions: [],
            normals: [],
            textureCoordinates: [],
            indices: fullGridIndices(resolution: 5)
        )

        let full = geometry.indices(for: .lod0)
        let lod1 = geometry.indices(for: .lod1)
        let topEdgeCells: [UInt32] = [
            [UInt32(0), 5, 1, 1, 5, 6],
            [UInt32(1), 6, 2, 2, 6, 7],
            [UInt32(2), 7, 3, 3, 7, 8],
            [UInt32(3), 8, 4, 4, 8, 9],
        ].reduce(into: []) { result, cell in
            result.append(contentsOf: cell)
        }

        XCTAssertLessThan(lod1.count, full.count)
        XCTAssertTrue(topEdgeCells.allSatisfy { lod1.contains($0) })
    }

    private func fullGridIndices(resolution: Int) -> [UInt32] {
        var indices: [UInt32] = []

        for localZ in 0..<(resolution - 1) {
            for localX in 0..<(resolution - 1) {
                let topLeft = UInt32(localZ * resolution + localX)
                let topRight = UInt32(localZ * resolution + localX + 1)
                let bottomLeft = UInt32((localZ + 1) * resolution + localX)
                let bottomRight = UInt32((localZ + 1) * resolution + localX + 1)

                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)
                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }

        return indices
    }
}
