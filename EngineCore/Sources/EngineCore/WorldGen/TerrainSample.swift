public struct TerrainSample: Equatable, Hashable, Codable, Sendable {
    public let localX: Int
    public let localZ: Int
    public let worldX: Int
    public let worldZ: Int
    public let height: Float

    public init(localX: Int, localZ: Int, worldX: Int, worldZ: Int, height: Float) {
        self.localX = localX
        self.localZ = localZ
        self.worldX = worldX
        self.worldZ = worldZ
        self.height = height
    }
}
