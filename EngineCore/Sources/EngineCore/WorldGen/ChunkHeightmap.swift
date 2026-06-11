public struct ChunkHeightmap: Equatable, Codable, Sendable {
    public static let resolution = 64
    public static let gridStride = resolution - 1
    public static let sampleCount = resolution * resolution

    public let seed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let samples: [TerrainSample]

    public init(seed: WorldSeed, coordinate: ChunkCoordinate, samples: [TerrainSample]) {
        precondition(samples.count == Self.sampleCount, "ChunkHeightmap requires exactly 64x64 samples.")

        self.seed = seed
        self.coordinate = coordinate
        self.samples = samples
    }

    public subscript(localX: Int, localZ: Int) -> TerrainSample {
        sample(localX: localX, localZ: localZ)
    }

    public func sample(localX: Int, localZ: Int) -> TerrainSample {
        precondition(Self.contains(localX: localX, localZ: localZ), "ChunkHeightmap sample index out of bounds.")

        return samples[Self.index(localX: localX, localZ: localZ)]
    }

    public func height(localX: Int, localZ: Int) -> Float {
        sample(localX: localX, localZ: localZ).height
    }

    public static func contains(localX: Int, localZ: Int) -> Bool {
        (0..<resolution).contains(localX) && (0..<resolution).contains(localZ)
    }

    public var stableHash: UInt64 {
        var hasher = StableHash.Builder()
        hasher.combine(seed)
        hasher.combine(coordinate)
        hasher.combine(Self.resolution)

        for sample in samples {
            hasher.combine(sample.localX)
            hasher.combine(sample.localZ)
            hasher.combine(sample.worldX)
            hasher.combine(sample.worldZ)
            hasher.combine(sample.height)
        }

        return hasher.finalize().value
    }

    private static func index(localX: Int, localZ: Int) -> Int {
        localZ * resolution + localX
    }
}
