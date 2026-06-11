public struct RopeAnchorCandidate: Equatable, Hashable, Codable, Sendable {
    public let id: UInt64
    public let coordinate: ChunkCoordinate
    public let localX: Int
    public let localZ: Int
    public let anchorPosition: WorldPosition
    public let lowerPosition: WorldPosition
    public let verticalDistance: Float
    public let rockStability: Float
    public let topAccessScore: Float
    public let bottomAccessScore: Float
    public let score: Float

    public init(
        id: UInt64,
        coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        anchorPosition: WorldPosition,
        lowerPosition: WorldPosition,
        verticalDistance: Float,
        rockStability: Float,
        topAccessScore: Float,
        bottomAccessScore: Float,
        score: Float
    ) {
        self.id = id
        self.coordinate = coordinate
        self.localX = localX
        self.localZ = localZ
        self.anchorPosition = anchorPosition
        self.lowerPosition = lowerPosition
        self.verticalDistance = max(verticalDistance, 0)
        self.rockStability = Self.clamped01(rockStability)
        self.topAccessScore = Self.clamped01(topAccessScore)
        self.bottomAccessScore = Self.clamped01(bottomAccessScore)
        self.score = Self.clamped01(score)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
