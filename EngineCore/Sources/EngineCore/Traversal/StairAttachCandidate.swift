public struct StairAttachCandidate: Equatable, Hashable, Codable, Sendable {
    public let id: UInt64
    public let coordinate: ChunkCoordinate
    public let localX: Int
    public let localZ: Int
    public let start: WorldPosition
    public let end: WorldPosition
    public let stepCount: Int
    public let widthScore: Float
    public let slopeDegrees: Float
    public let attachableScore: Float
    public let difficulty: Float

    public init(
        id: UInt64,
        coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        start: WorldPosition,
        end: WorldPosition,
        stepCount: Int,
        widthScore: Float,
        slopeDegrees: Float,
        attachableScore: Float,
        difficulty: Float
    ) {
        self.id = id
        self.coordinate = coordinate
        self.localX = localX
        self.localZ = localZ
        self.start = start
        self.end = end
        self.stepCount = max(stepCount, 1)
        self.widthScore = Self.clamped01(widthScore)
        self.slopeDegrees = max(slopeDegrees, 0)
        self.attachableScore = Self.clamped01(attachableScore)
        self.difficulty = Self.clamped01(difficulty)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
