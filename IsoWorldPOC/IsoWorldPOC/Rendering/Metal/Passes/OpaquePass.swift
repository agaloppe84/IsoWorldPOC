//
//  OpaquePass.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import Metal

struct OpaquePass: RenderPass {
    static let passDescriptor = RenderPassDescriptor(
        kind: .opaque,
        name: "Opaque",
        reads: [.worldGeometry],
        writes: [.backbuffer, .depth],
        isOptional: false
    )

    let descriptor = Self.passDescriptor

    private let terrainPass = MetalTerrainPass()
    private let propPass = MetalPropPass()
    private let playerPass = MetalPlayerPass()

    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        var metrics = MetalFrameDrawMetrics.empty

        if context.shouldRenderTerrain {
            metrics.add(terrainPass.encode(context: context, renderEncoder: renderEncoder))
        }

        if context.shouldRenderProps {
            metrics.add(propPass.encode(context: context, renderEncoder: renderEncoder))
        }

        if context.shouldRenderPlayer {
            metrics.add(playerPass.encode(context: context, renderEncoder: renderEncoder))
        }

        return metrics
    }
}
