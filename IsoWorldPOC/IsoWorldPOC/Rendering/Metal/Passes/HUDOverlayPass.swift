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
    private let renderer: UIMetalRenderer?

    init(device: MTLDevice? = nil) {
        self.renderer = UIMetalRenderer(device: device)
    }

    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        renderer?.encode(
            snapshot: context.snapshot.ui,
            drawableSize: context.drawableSize,
            renderEncoder: renderEncoder
        ) ?? .empty
    }
}
