public struct PropPlacement: Equatable, Hashable, Codable, Sendable {
    public let placementIndex: Int
    public let type: PropType
    public let localX: Float
    public let localZ: Float
    public let worldX: Float
    public let worldZ: Float
    public let rotationRadians: Float
    public let scale: Float

    public init(
        placementIndex: Int = 0,
        type: PropType,
        localX: Float,
        localZ: Float,
        worldX: Float,
        worldZ: Float,
        rotationRadians: Float,
        scale: Float
    ) {
        self.placementIndex = placementIndex
        self.type = type
        self.localX = localX
        self.localZ = localZ
        self.worldX = worldX
        self.worldZ = worldZ
        self.rotationRadians = rotationRadians
        self.scale = scale
    }
}
