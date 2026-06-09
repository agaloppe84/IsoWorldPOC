public struct ChunkCoordinate: Hashable, Codable, Sendable {
    public static let origin = ChunkCoordinate(x: 0, y: 0, z: 0)

    public let x: Int
    public let y: Int
    public let z: Int

    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    public func offsetBy(x deltaX: Int = 0, y deltaY: Int = 0, z deltaZ: Int = 0) -> ChunkCoordinate {
        ChunkCoordinate(
            x: x + deltaX,
            y: y + deltaY,
            z: z + deltaZ
        )
    }
}

