import Foundation
import XCTest
@testable import EngineCore

final class SnapshotContractTests: XCTestCase {
    func testEngineFrameSnapshotRoundTripsThroughJSON() throws {
        let render = makeRenderSnapshot()
        let debug = DebugSnapshot(
            frameIndex: 7,
            currentChunk: .origin,
            activeChunkCount: 1,
            visibleChunkCount: 1,
            generatedChunkCount: 3,
            cachedChunkCount: 3,
            approximateTriangleCount: render.approximateTriangleCount,
            approximatePropCount: render.visiblePropCount,
            jobs: JobSchedulerSnapshot(
                activeJobCount: 1,
                submittedJobCount: 4,
                succeededJobCount: 3,
                cancelledJobCount: 0,
                failedJobCount: 0
            ),
            chunksReadyForUpload: 2,
            chunkUploadsThisFrame: 1,
            averageChunkDataGenerationTimeMs: 1.5
        )
        let snapshot = EngineFrameSnapshot(
            frameIndex: 7,
            worldSeed: WorldSeed(99),
            simulationTime: 1.25,
            deltaTime: 0.016,
            render: render,
            debug: debug
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(EngineFrameSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testToolPreviewSnapshotClampsProgressAndDoesNotRequireWorldMutation() {
        let render = makeRenderSnapshot()
        let preview = ToolPreviewSnapshot(
            id: StableID.make(worldSeed: WorldSeed(1), domain: .style),
            toolName: "terrain-preview",
            worldSeed: WorldSeed(1),
            status: .ready,
            progress: 1.5,
            render: render,
            message: "ready"
        )

        XCTAssertEqual(preview.progress, 1)
        XCTAssertEqual(preview.render, render)
        XCTAssertEqual(preview.status, .ready)
    }

    func testRenderSnapshotAggregatesVisibleCounts() {
        let snapshot = makeRenderSnapshot()

        XCTAssertEqual(snapshot.visibleChunkCount, 1)
        XCTAssertEqual(snapshot.visiblePropCount, 0)
        XCTAssertEqual(snapshot.approximateTriangleCount, 12)
        XCTAssertEqual(snapshot.environment.surfaceState, .dry)
        XCTAssertGreaterThan(snapshot.environment.toneMapping.exposure, 0)
    }

    private func makeRenderSnapshot() -> RenderWorldSnapshot {
        RenderWorldSnapshot(
            camera: CameraRenderState(
                position: WorldPosition(x: 0, y: 3, z: 6),
                target: WorldPosition(x: 0, y: 0, z: 0),
                fieldOfViewDegrees: 35,
                yaw: 0,
                pitch: -0.4,
                distance: 6
            ),
            chunks: [
                RenderChunk(
                    coordinate: .origin,
                    origin: WorldPosition(x: 0, y: 0, z: 0),
                    terrainGeometry: TerrainGeometryBuffers(
                        resolution: 2,
                        positions: [
                            TerrainGeometryBuffers.Position(x: 0, y: 0, z: 0),
                            TerrainGeometryBuffers.Position(x: 1, y: 0, z: 0),
                            TerrainGeometryBuffers.Position(x: 0, y: 0, z: 1),
                            TerrainGeometryBuffers.Position(x: 1, y: 0, z: 1),
                        ],
                        normals: [
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                        ],
                        textureCoordinates: [
                            TerrainGeometryBuffers.TextureCoordinate(u: 0, v: 0),
                            TerrainGeometryBuffers.TextureCoordinate(u: 1, v: 0),
                            TerrainGeometryBuffers.TextureCoordinate(u: 0, v: 1),
                            TerrainGeometryBuffers.TextureCoordinate(u: 1, v: 1),
                        ],
                        indices: [0, 2, 1, 1, 2, 3]
                    ),
                    biome: Biome.definition(for: .grassland),
                    terrainMaterial: Biome.definition(for: .grassland).terrainMaterial,
                    terrainVertexMaterials: [],
                    props: [],
                    isVisible: true,
                    approximateTriangleCount: 12
                ),
                RenderChunk(
                    coordinate: ChunkCoordinate(x: 1, y: 0, z: 0),
                    origin: WorldPosition(x: 1, y: 0, z: 0),
                    terrainGeometry: TerrainGeometryBuffers(
                        resolution: 2,
                        positions: [
                            TerrainGeometryBuffers.Position(x: 0, y: 0, z: 0),
                            TerrainGeometryBuffers.Position(x: 1, y: 0, z: 0),
                            TerrainGeometryBuffers.Position(x: 0, y: 0, z: 1),
                            TerrainGeometryBuffers.Position(x: 1, y: 0, z: 1),
                        ],
                        normals: [
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                            TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0),
                        ],
                        textureCoordinates: [
                            TerrainGeometryBuffers.TextureCoordinate(u: 0, v: 0),
                            TerrainGeometryBuffers.TextureCoordinate(u: 1, v: 0),
                            TerrainGeometryBuffers.TextureCoordinate(u: 0, v: 1),
                            TerrainGeometryBuffers.TextureCoordinate(u: 1, v: 1),
                        ],
                        indices: [0, 2, 1, 1, 2, 3]
                    ),
                    biome: Biome.definition(for: .temperateForest),
                    terrainMaterial: Biome.definition(for: .temperateForest).terrainMaterial,
                    terrainVertexMaterials: [],
                    props: [],
                    isVisible: false,
                    approximateTriangleCount: 24
                ),
            ]
        )
    }
}
