public struct LedgeCandidate: Equatable, Hashable, Codable, Sendable {
    public let id: UInt64
    public let coordinate: ChunkCoordinate
    public let localX: Int
    public let localZ: Int
    public let position: WorldPosition
    public let normal: WorldPosition
    public let slopeDegrees: Float
    public let rockStability: Float
    public let ledgeScore: Float
    public let climbGrip: Float
    public let fallHeight: Float
    public let topAccessScore: Float
    public let bottomAccessScore: Float
    public let attachableScore: Float

    public init(
        id: UInt64,
        coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        position: WorldPosition,
        normal: WorldPosition,
        slopeDegrees: Float,
        rockStability: Float,
        ledgeScore: Float,
        climbGrip: Float,
        fallHeight: Float,
        topAccessScore: Float,
        bottomAccessScore: Float,
        attachableScore: Float
    ) {
        self.id = id
        self.coordinate = coordinate
        self.localX = localX
        self.localZ = localZ
        self.position = position
        self.normal = normal
        self.slopeDegrees = max(slopeDegrees, 0)
        self.rockStability = Self.clamped01(rockStability)
        self.ledgeScore = Self.clamped01(ledgeScore)
        self.climbGrip = Self.clamped01(climbGrip)
        self.fallHeight = max(fallHeight, 0)
        self.topAccessScore = Self.clamped01(topAccessScore)
        self.bottomAccessScore = Self.clamped01(bottomAccessScore)
        self.attachableScore = Self.clamped01(attachableScore)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
