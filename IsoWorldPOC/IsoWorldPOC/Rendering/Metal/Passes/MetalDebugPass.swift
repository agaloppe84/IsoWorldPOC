//
//  MetalDebugPass.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import Metal

struct MetalDebugPass {
    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder,
        depthStencilState: MTLDepthStencilState?
    ) -> MetalFrameDrawMetrics {
        guard context.snapshot.debugOptions.showChunkBounds else {
            return .empty
        }

        if let depthStencilState {
            renderEncoder.setDepthStencilState(depthStencilState)
        }

        var metrics = MetalFrameDrawMetrics.empty

        for chunk in context.visibleChunks {
            guard
                let buffers = context.chunkBuffersByCoordinate[chunk.coordinate],
                buffers.debugBoundsLineVertexCount > 0
            else {
                continue
            }

            var uniforms = makeMetalUniforms(
                origin: chunk.origin,
                viewProjectionMatrix: context.viewProjectionMatrix
            )
            renderEncoder.setVertexBuffer(buffers.debugBoundsLineVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(
                &uniforms,
                length: MemoryLayout<MetalTerrainUniforms>.stride,
                index: 1
            )
            renderEncoder.drawPrimitives(
                type: .line,
                vertexStart: 0,
                vertexCount: buffers.debugBoundsLineVertexCount
            )

            metrics.debugDrawCalls += 1
            metrics.debugBoundsDrawn += 1
        }

        return metrics
    }
}
