public enum ToolPreviewStatus: String, Codable, Sendable {
    case queued
    case running
    case ready
    case cancelled
    case failed
}

public struct ToolPreviewSnapshot: Equatable, Codable, Sendable {
    public let id: StableID
    public let toolName: String
    public let worldSeed: WorldSeed
    public let status: ToolPreviewStatus
    public let progress: Float
    public let render: RenderWorldSnapshot?
    public let message: String?

    public init(
        id: StableID,
        toolName: String,
        worldSeed: WorldSeed,
        status: ToolPreviewStatus,
        progress: Float,
        render: RenderWorldSnapshot? = nil,
        message: String? = nil
    ) {
        precondition(!toolName.isEmpty, "toolName cannot be empty.")

        self.id = id
        self.toolName = toolName
        self.worldSeed = worldSeed
        self.status = status
        self.progress = min(max(progress, 0), 1)
        self.render = render
        self.message = message
    }
}
