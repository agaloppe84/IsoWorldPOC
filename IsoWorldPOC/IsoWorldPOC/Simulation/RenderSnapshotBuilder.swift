//
//  RenderSnapshotBuilder.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Foundation

struct RenderSnapshotBuildTiming: Equatable {
    static let empty = RenderSnapshotBuildTiming()

    var activeChunkDataMs: Float = 0
    var renderChunksMs: Float = 0
    var renderPropsMs: Float = 0
    var terrainSamplePropsMs: Float = 0
    var chunkCount = 0
    var propCount = 0
}

struct RenderSnapshotBuildResult {
    let snapshot: RenderWorldSnapshot
    let timing: RenderSnapshotBuildTiming
}

struct RenderSnapshotDebugOptions {
    static let defaults = RenderSnapshotDebugOptions(
        showChunkBounds: true,
        renderTerrain: true,
        renderProps: true,
        renderPlayer: true,
        terrainMaterialDebugMode: .normal,
        terrainSplatDebugLayerIndex: 0,
        freezeSimulation: false,
        freezeChunkStreaming: false,
        forcedLODLevel: nil
    )

    let showChunkBounds: Bool
    let renderTerrain: Bool
    let renderProps: Bool
    let renderPlayer: Bool
    let terrainMaterialDebugMode: TerrainMaterialDebugMode
    let terrainSplatDebugLayerIndex: Int
    let freezeSimulation: Bool
    let freezeChunkStreaming: Bool
    let forcedLODLevel: LODLevel?
}

@MainActor
struct RenderSnapshotBuilder {
    func makeSnapshot(
        chunkStreamer: ChunkDataStreamer,
        camera: CameraRenderState,
        lighting: LightingState,
        debugOptions: RenderSnapshotDebugOptions
    ) -> RenderWorldSnapshot {
        makeInstrumentedSnapshot(
            chunkStreamer: chunkStreamer,
            camera: camera,
            lighting: lighting,
            debugOptions: debugOptions
        ).snapshot
    }

    func makeInstrumentedSnapshot(
        chunkStreamer: ChunkDataStreamer,
        camera: CameraRenderState,
        lighting: LightingState,
        debugOptions: RenderSnapshotDebugOptions
    ) -> RenderSnapshotBuildResult {
        let activeChunkDataStart = currentTimeMilliseconds()
        let activeChunkData = chunkStreamer.activeChunkData()
        let activeChunkDataMs = Float(currentTimeMilliseconds() - activeChunkDataStart)

        var renderPropsMs: Float = 0
        var terrainSamplePropsMs: Float = 0
        let renderChunksStart = currentTimeMilliseconds()
        let chunks = activeChunkData.map { renderData in
            renderChunk(
                from: renderData,
                debugOptions: debugOptions,
                renderPropsMs: &renderPropsMs,
                terrainSamplePropsMs: &terrainSamplePropsMs
            )
        }
        let renderChunksMs = Float(currentTimeMilliseconds() - renderChunksStart)

        let snapshot = RenderWorldSnapshot(
            camera: camera,
            lighting: lighting,
            chunks: chunks,
            debugOptions: RenderDebugOptions(
                showChunkBounds: debugOptions.showChunkBounds,
                renderTerrain: debugOptions.renderTerrain,
                renderProps: debugOptions.renderProps,
                renderPlayer: debugOptions.renderPlayer,
                terrainMaterialDebugMode: debugOptions.terrainMaterialDebugMode,
                terrainSplatDebugLayerIndex: debugOptions.terrainSplatDebugLayerIndex
            )
        )

        let timing = RenderSnapshotBuildTiming(
            activeChunkDataMs: activeChunkDataMs,
            renderChunksMs: renderChunksMs,
            renderPropsMs: renderPropsMs,
            terrainSamplePropsMs: terrainSamplePropsMs,
            chunkCount: activeChunkData.count,
            propCount: chunks.reduce(0) { $0 + $1.props.count }
        )

        return RenderSnapshotBuildResult(snapshot: snapshot, timing: timing)
    }

    private func renderChunk(
        from renderData: ChunkStreamerRenderData,
        debugOptions: RenderSnapshotDebugOptions,
        renderPropsMs: inout Float,
        terrainSamplePropsMs: inout Float
    ) -> RenderChunk {
        let data = renderData.data
        let origin = WorldPosition(x: data.originX, y: 0, z: data.originZ)
        let propsStart = currentTimeMilliseconds()
        let props = renderProps(
            from: data,
            isVisible: renderData.isVisible && renderData.lodSelection.rendersProps,
            isEnabled: debugOptions.renderProps,
            terrainSamplePropsMs: &terrainSamplePropsMs
        )
        renderPropsMs += Float(currentTimeMilliseconds() - propsStart)

        return RenderChunk(
            coordinate: data.coordinate,
            origin: origin,
            terrainGeometry: data.terrainGeometry,
            biome: data.biome,
            terrainMaterial: data.biome.terrainMaterial,
            terrainVertexMaterials: data.terrainVertexMaterials,
            props: props,
            debugBounds: debugBounds(
                coordinate: data.coordinate,
                origin: origin,
                state: renderData.debugState,
                isEnabled: debugOptions.showChunkBounds
            ),
            isVisible: renderData.isVisible,
            lodSelection: renderData.lodSelection,
            approximateTriangleCount: data.terrainGeometry.triangleCount(for: renderData.lodSelection.level)
        )
    }

    private func renderProps(
        from data: ProceduralChunkData,
        isVisible: Bool,
        isEnabled: Bool,
        terrainSamplePropsMs: inout Float
    ) -> [RenderProp] {
        guard isEnabled else {
            return []
        }

        let sampler = TerrainSampler(
            geometry: data.terrainGeometry,
            originX: data.originX,
            originZ: data.originZ
        )

        return data.propVariants.map { variant in
            let localX = variant.placement.localX * ProceduralChunkDataFactory.horizontalScale
            let localZ = variant.placement.localZ * ProceduralChunkDataFactory.horizontalScale
            let worldX = data.originX + localX
            let worldZ = data.originZ + localZ
            let sampleStart = currentTimeMilliseconds()
            let terrainHeight = sampler.heightAt(x: worldX, z: worldZ)
            terrainSamplePropsMs += Float(currentTimeMilliseconds() - sampleStart)

            return RenderProp(
                variant: variant,
                worldPosition: WorldPosition(
                    x: worldX,
                    y: terrainHeight + 0.02,
                    z: worldZ
                ),
                rotationRadians: variant.placement.rotationRadians,
                isVisible: isVisible
            )
        }
    }

    private func debugBounds(
        coordinate: ChunkCoordinate,
        origin: WorldPosition,
        state: RenderChunkDebugState,
        isEnabled: Bool
    ) -> RenderChunkDebugBounds? {
        guard isEnabled else {
            return nil
        }

        return RenderChunkDebugBounds(
            coordinate: coordinate,
            origin: origin,
            size: PropVector3(
                x: ProceduralChunkDataFactory.chunkWorldSize,
                y: 2.5,
                z: ProceduralChunkDataFactory.chunkWorldSize
            ),
            state: state
        )
    }

    private func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
