public struct WorldPosition: Equatable, Hashable, Codable, Sendable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct ChunkLocalCoordinate: Equatable, Hashable, Codable, Sendable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public extension ChunkCoordinate {
    static func containing(_ position: WorldPosition, chunkSize: Float) -> ChunkCoordinate {
        precondition(chunkSize > 0, "chunkSize must be positive.")

        return ChunkCoordinate(
            x: chunkIndex(for: position.x, chunkSize: chunkSize),
            y: chunkIndex(for: position.y, chunkSize: chunkSize),
            z: chunkIndex(for: position.z, chunkSize: chunkSize)
        )
    }

    func localCoordinate(for position: WorldPosition, chunkSize: Float) -> ChunkLocalCoordinate {
        precondition(chunkSize > 0, "chunkSize must be positive.")

        return ChunkLocalCoordinate(
            x: localCoordinate(for: position.x, chunkIndex: x, chunkSize: chunkSize),
            y: localCoordinate(for: position.y, chunkIndex: y, chunkSize: chunkSize),
            z: localCoordinate(for: position.z, chunkIndex: z, chunkSize: chunkSize)
        )
    }

    func worldOrigin(chunkSize: Float) -> WorldPosition {
        precondition(chunkSize > 0, "chunkSize must be positive.")

        return WorldPosition(
            x: Float(x) * chunkSize,
            y: Float(y) * chunkSize,
            z: Float(z) * chunkSize
        )
    }

    func worldPosition(for localCoordinate: ChunkLocalCoordinate, chunkSize: Float) -> WorldPosition {
        precondition(chunkSize > 0, "chunkSize must be positive.")

        let origin = worldOrigin(chunkSize: chunkSize)

        return WorldPosition(
            x: origin.x + localCoordinate.x,
            y: origin.y + localCoordinate.y,
            z: origin.z + localCoordinate.z
        )
    }

    static func localCoordinate(
        for position: WorldPosition,
        chunkSize: Float
    ) -> ChunkLocalCoordinate {
        containing(position, chunkSize: chunkSize).localCoordinate(
            for: position,
            chunkSize: chunkSize
        )
    }

    private static func chunkIndex(for value: Float, chunkSize: Float) -> Int {
        Int((value / chunkSize).rounded(.down))
    }

    private func localCoordinate(for value: Float, chunkIndex: Int, chunkSize: Float) -> Float {
        value - Float(chunkIndex) * chunkSize
    }
}
