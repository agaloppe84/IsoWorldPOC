public struct RegionCoordinate: Hashable, Codable, Sendable {
    public static let origin = RegionCoordinate(x: 0, y: 0, z: 0)

    public let x: Int
    public let y: Int
    public let z: Int

    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static func containing(
        _ coordinate: ChunkCoordinate,
        regionSizeInChunks: Int
    ) -> RegionCoordinate {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive.")

        return RegionCoordinate(
            x: floorDiv(coordinate.x, by: regionSizeInChunks),
            y: floorDiv(coordinate.y, by: regionSizeInChunks),
            z: floorDiv(coordinate.z, by: regionSizeInChunks)
        )
    }

    public func chunkOrigin(regionSizeInChunks: Int) -> ChunkCoordinate {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive.")

        return ChunkCoordinate(
            x: x * regionSizeInChunks,
            y: y * regionSizeInChunks,
            z: z * regionSizeInChunks
        )
    }

    private static func floorDiv(_ value: Int, by divisor: Int) -> Int {
        let quotient = value / divisor
        let remainder = value % divisor

        if remainder < 0 {
            return quotient - 1
        }

        return quotient
    }
}

public typealias RegionCoord = RegionCoordinate
