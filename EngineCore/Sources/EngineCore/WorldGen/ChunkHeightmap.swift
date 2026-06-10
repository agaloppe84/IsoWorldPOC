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
        var hasher = StableTerrainHasher()
        hasher.mix(seed.value)
        hasher.mix(coordinate.x)
        hasher.mix(coordinate.y)
        hasher.mix(coordinate.z)
        hasher.mix(Self.resolution)

        for sample in samples {
            hasher.mix(sample.localX)
            hasher.mix(sample.localZ)
            hasher.mix(sample.worldX)
            hasher.mix(sample.worldZ)
            hasher.mix(sample.height)
        }

        return hasher.value
    }

    private static func index(localX: Int, localZ: Int) -> Int {
        localZ * resolution + localX
    }
}

private struct StableTerrainHasher {
    private(set) var value: UInt64 = 0xcbf2_9ce4_8422_2325

    mutating func mix(_ value: UInt64) {
        self.value ^= value
        self.value &*= 0x0000_0100_0000_01b3
    }

    mutating func mix(_ value: Int) {
        mix(UInt64(bitPattern: Int64(value)))
    }

    mutating func mix(_ value: Float) {
        mix(UInt64(value.bitPattern))
    }
}
