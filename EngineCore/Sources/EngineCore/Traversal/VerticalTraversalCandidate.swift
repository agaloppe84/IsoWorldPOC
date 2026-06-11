public enum VerticalTraversalKind: String, CaseIterable, Codable, Sendable {
    case naturalLedges
    case rope
    case carvedStairs
    case climbingWall
}

public enum TraversalTool: String, CaseIterable, Codable, Sendable {
    case none
    case rope
    case climbingGear
}

public struct VerticalTraversalCandidate: Equatable, Hashable, Codable, Sendable {
    public let id: UInt64
    public let kind: VerticalTraversalKind
    public let coordinate: ChunkCoordinate
    public let sourceLocalX: Int
    public let sourceLocalZ: Int
    public let start: WorldPosition
    public let end: WorldPosition
    public let difficulty: Float
    public let confidence: Float
    public let requiredTool: TraversalTool

    public init(
        id: UInt64,
        kind: VerticalTraversalKind,
        coordinate: ChunkCoordinate,
        sourceLocalX: Int,
        sourceLocalZ: Int,
        start: WorldPosition,
        end: WorldPosition,
        difficulty: Float,
        confidence: Float,
        requiredTool: TraversalTool = .none
    ) {
        self.id = id
        self.kind = kind
        self.coordinate = coordinate
        self.sourceLocalX = sourceLocalX
        self.sourceLocalZ = sourceLocalZ
        self.start = start
        self.end = end
        self.difficulty = Self.clamped01(difficulty)
        self.confidence = Self.clamped01(confidence)
        self.requiredTool = requiredTool
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
