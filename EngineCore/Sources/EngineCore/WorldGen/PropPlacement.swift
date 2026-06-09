public struct PropPlacement: Equatable, Hashable, Codable, Sendable {
    public let type: PropType
    public let localX: Float
    public let localZ: Float
    public let worldX: Float
    public let worldZ: Float
    public let rotationRadians: Float
    public let scale: Float

    public init(
        type: PropType,
        localX: Float,
        localZ: Float,
        worldX: Float,
        worldZ: Float,
        rotationRadians: Float,
        scale: Float
    ) {
        self.type = type
        self.localX = localX
        self.localZ = localZ
        self.worldX = worldX
        self.worldZ = worldZ
        self.rotationRadians = rotationRadians
        self.scale = scale
    }
}
