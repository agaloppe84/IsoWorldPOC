//
//  MetalPropPass.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import Metal

struct MetalPropPass {
    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        var metrics = MetalFrameDrawMetrics.empty

        for chunk in context.visibleChunks {
            guard
                let buffers = context.chunkBuffersByCoordinate[chunk.coordinate],
                let propVertexBuffer = buffers.propVertexBuffer,
                let propIndexBuffer = buffers.propIndexBuffer,
                buffers.propIndexCount > 0
            else {
                continue
            }

            var uniforms = makeMetalUniforms(
                origin: chunk.origin,
                viewProjectionMatrix: context.viewProjectionMatrix
            )
            renderEncoder.setVertexBuffer(propVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(
                &uniforms,
                length: MemoryLayout<MetalTerrainUniforms>.stride,
                index: 1
            )
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: buffers.propIndexCount,
                indexType: .uint32,
                indexBuffer: propIndexBuffer,
                indexBufferOffset: 0
            )

            metrics.propDrawCalls += 1
            metrics.propChunksDrawn += 1
            metrics.propsDrawn += chunk.props.filter(\.isVisible).count
        }

        return metrics
    }
}
