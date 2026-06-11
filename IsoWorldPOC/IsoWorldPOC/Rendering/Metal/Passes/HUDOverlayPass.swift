//
//  HUDOverlayPass.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import Metal

struct HUDOverlayPass: RenderPass {
    static let passDescriptor = RenderPassDescriptor(
        kind: .hudOverlay,
        name: "HUD Overlay",
        reads: [.hudGeometry],
        writes: [.backbuffer],
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
