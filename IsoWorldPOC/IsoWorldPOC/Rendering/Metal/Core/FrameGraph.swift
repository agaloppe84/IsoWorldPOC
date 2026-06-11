//
//  FrameGraph.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

struct FrameGraph {
    let passDescriptors: [RenderPassDescriptor]

    static let worldRenderer = FrameGraph(passDescriptors: [
        DepthPrepass.passDescriptor,
        OpaquePass.passDescriptor,
        DebugOverlayPass.passDescriptor,
        HUDOverlayPass.passDescriptor,
    ])

    func makePlan(for context: RenderFrameContext) -> RenderFramePlan {
        RenderFramePlan(
            passes: passDescriptors.map { descriptor in
                RenderFramePassPlan(
                    descriptor: descriptor,
                    isEnabled: isEnabled(descriptor.kind, for: context)
                )
            }
        )
    }

    private func isEnabled(
        _ passKind: RenderPassKind,
        for context: RenderFrameContext
    ) -> Bool {
        switch passKind {
        case .depthPrepass:
            return false
        case .opaque:
            return context.playerBuffers != nil || context.visibleChunks.contains { chunk in
                context.chunkBuffersByCoordinate[chunk.coordinate] != nil
            }
        case .debugOverlay:
            return context.snapshot.debugOptions.showChunkBounds &&
                context.visibleChunks.contains { chunk in
                    guard let buffers = context.chunkBuffersByCoordinate[chunk.coordinate] else {
                        return false
                    }

                    return buffers.debugBoundsLineVertexCount > 0
                }
        case .hudOverlay:
            return false
        }
    }
}

struct RenderFramePlan: Hashable {
    static let empty = RenderFramePlan(passes: [])

    let passes: [RenderFramePassPlan]

    var enabledPasses: [RenderFramePassPlan] {
        passes.filter(\.isEnabled)
    }

    var passCount: Int {
        passes.count
    }

    var enabledPassCount: Int {
        enabledPasses.count
    }
}

struct RenderFramePassPlan: Hashable {
    let descriptor: RenderPassDescriptor
    let isEnabled: Bool
}
