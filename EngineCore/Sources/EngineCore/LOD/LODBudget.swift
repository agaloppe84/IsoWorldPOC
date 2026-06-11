public struct LODBudget: Equatable, Codable, Sendable {
    public let maxVisibleChunks: Int
    public let maxTerrainDrawCalls: Int
    public let maxPropDrawCalls: Int

    public init(
        maxVisibleChunks: Int,
        maxTerrainDrawCalls: Int? = nil,
        maxPropDrawCalls: Int? = nil
    ) {
        let visibleChunks = max(maxVisibleChunks, 1)

        self.maxVisibleChunks = visibleChunks
        self.maxTerrainDrawCalls = max(maxTerrainDrawCalls ?? visibleChunks, 1)
        self.maxPropDrawCalls = max(maxPropDrawCalls ?? visibleChunks, 1)
    }
}
