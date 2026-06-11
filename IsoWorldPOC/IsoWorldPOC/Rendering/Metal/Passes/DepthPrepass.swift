//
//  DepthPrepass.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import Metal

struct DepthPrepass: RenderPass {
    static let passDescriptor = RenderPassDescriptor(
        kind: .depthPrepass,
        name: "Depth Prepass",
        reads: [.worldGeometry],
        writes: [.depth],
        isOptional: true
    )

    let descriptor = Self.passDescriptor

    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        .empty
    }
}
