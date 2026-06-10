//
//  MetalPlayerPass.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import Metal

struct MetalPlayerPass {
    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        guard let playerBuffers = context.playerBuffers else {
            return .empty
        }

        var uniforms = makeMetalUniforms(
            modelMatrix: matrixTranslation(context.playerPosition),
            viewProjectionMatrix: context.viewProjectionMatrix
        )
        renderEncoder.setVertexBuffer(playerBuffers.vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(
            &uniforms,
            length: MemoryLayout<MetalTerrainUniforms>.stride,
            index: 1
        )
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: playerBuffers.indexCount,
            indexType: .uint32,
            indexBuffer: playerBuffers.indexBuffer,
            indexBufferOffset: 0
        )

        var metrics = MetalFrameDrawMetrics.empty
        metrics.playerDrawCalls = 1
        return metrics
    }
}
