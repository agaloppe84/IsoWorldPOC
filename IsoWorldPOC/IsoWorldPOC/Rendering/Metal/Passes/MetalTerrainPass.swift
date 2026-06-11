//
//  MetalTerrainPass.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import Metal

struct MetalTerrainPass {
    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        var metrics = MetalFrameDrawMetrics.empty

        for chunk in context.visibleChunks {
            guard let buffers = context.chunkBuffersByCoordinate[chunk.coordinate] else {
                continue
            }

            var uniforms = makeMetalUniforms(
                origin: chunk.origin,
                viewProjectionMatrix: context.viewProjectionMatrix
            )
            renderEncoder.setVertexBuffer(buffers.terrainVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(
                &uniforms,
                length: MemoryLayout<MetalTerrainUniforms>.stride,
                index: 1
            )
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: buffers.terrainIndexCount,
                indexType: .uint32,
                indexBuffer: buffers.terrainIndexBuffer,
                indexBufferOffset: 0
            )

            metrics.terrainDrawCalls += 1
            metrics.terrainChunksDrawn += 1
            metrics.terrainIndicesDrawn += buffers.terrainIndexCount
        }

        return metrics
    }
}
