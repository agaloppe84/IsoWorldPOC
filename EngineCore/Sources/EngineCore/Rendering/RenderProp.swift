public struct RenderProp: Equatable, Codable, Sendable {
    public let variant: PropVariant
    public let worldPosition: WorldPosition
    public let rotationRadians: Float
    public let isVisible: Bool

    public init(
        variant: PropVariant,
        worldPosition: WorldPosition,
        rotationRadians: Float,
        isVisible: Bool = true
    ) {
        self.variant = variant
        self.worldPosition = worldPosition
        self.rotationRadians = rotationRadians
        self.isVisible = isVisible
    }
}
