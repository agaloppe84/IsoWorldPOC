//
//  DebugOverlayPass.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import Metal

struct DebugOverlayPass: RenderPass {
    static let passDescriptor = RenderPassDescriptor(
        kind: .debugOverlay,
        name: "Debug Overlay",
        reads: [.debugGeometry, .depth],
        writes: [.backbuffer],
        isOptional: true
    )

    let descriptor = Self.passDescriptor

    private let debugPass = MetalDebugPass()

    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder,
        depthStencilState: MTLDepthStencilState?
    ) -> MetalFrameDrawMetrics {
        debugPass.encode(
            context: context,
            renderEncoder: renderEncoder,
            depthStencilState: depthStencilState
        )
    }
}
