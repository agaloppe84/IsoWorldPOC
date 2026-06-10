public struct RenderDebugOptions: Equatable, Codable, Sendable {
    public let showChunkBounds: Bool
    public let showChunkLabels: Bool

    public init(showChunkBounds: Bool = false, showChunkLabels: Bool = false) {
        self.showChunkBounds = showChunkBounds
        self.showChunkLabels = showChunkLabels
    }
}

public struct RenderWorldSnapshot: Equatable, Codable, Sendable {
    public let camera: CameraRenderState
    public let chunks: [RenderChunk]
    public let debugOptions: RenderDebugOptions

    public var visibleChunkCount: Int {
        chunks.filter(\.isVisible).count
    }

    public var approximateTriangleCount: Int {
        chunks.reduce(0) { total, chunk in
            guard chunk.isVisible else {
                return total
            }

            return total + chunk.approximateTriangleCount
        }
    }

    public var visiblePropCount: Int {
        chunks.reduce(0) { total, chunk in
            guard chunk.isVisible else {
                return total
            }

            return total + chunk.props.filter(\.isVisible).count
        }
    }

    public init(
        camera: CameraRenderState,
        chunks: [RenderChunk],
        debugOptions: RenderDebugOptions = RenderDebugOptions()
    ) {
        self.camera = camera
        self.chunks = chunks
        self.debugOptions = debugOptions
    }
}
