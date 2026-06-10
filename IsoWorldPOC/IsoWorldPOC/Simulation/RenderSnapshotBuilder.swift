//
//  RenderSnapshotBuilder.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore

struct RenderSnapshotDebugOptions {
    static let defaults = RenderSnapshotDebugOptions(
        showChunkBounds: true,
        showChunkLabels: true
    )

    let showChunkBounds: Bool
    let showChunkLabels: Bool
}

@MainActor
struct RenderSnapshotBuilder {
    func makeSnapshot(
        chunkStreamer: ChunkDataStreamer,
        camera: CameraRenderState,
        lighting: LightingState,
        debugOptions: RenderSnapshotDebugOptions
    ) -> RenderWorldSnapshot {
        let chunks = chunkStreamer.activeChunkData().map { renderData in
            renderChunk(from: renderData)
        }

        return RenderWorldSnapshot(
            camera: camera,
            lighting: lighting,
            chunks: chunks,
            debugOptions: RenderDebugOptions(
                showChunkBounds: debugOptions.showChunkBounds,
                showChunkLabels: debugOptions.showChunkLabels
            )
        )
    }

    private func renderChunk(from renderData: ChunkStreamerRenderData) -> RenderChunk {
        let data = renderData.data
        let origin = WorldPosition(x: data.originX, y: 0, z: data.originZ)

        return RenderChunk(
            coordinate: data.coordinate,
            origin: origin,
            terrainGeometry: data.terrainGeometry,
            biome: data.biome,
            terrainMaterial: data.biome.terrainMaterial,
            terrainVertexMaterials: data.terrainVertexMaterials,
            props: renderProps(from: data, isVisible: renderData.isVisible),
            debugBounds: RenderChunkDebugBounds(
                coordinate: data.coordinate,
                origin: origin,
                size: PropVector3(
                    x: ProceduralChunkDataFactory.chunkWorldSize,
                    y: 2.5,
                    z: ProceduralChunkDataFactory.chunkWorldSize
                ),
                state: renderData.debugState
            ),
            isVisible: renderData.isVisible,
            approximateTriangleCount: data.meshIndices.count / 3
        )
    }

    private func renderProps(
        from data: ProceduralChunkData,
        isVisible: Bool
    ) -> [RenderProp] {
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
            let terrainHeight = sampler.heightAt(x: worldX, z: worldZ)

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
}
