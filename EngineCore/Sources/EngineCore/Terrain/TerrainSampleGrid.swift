public struct TerrainSampleGrid: Equatable, Codable, Sendable {
    public static let defaultResolution = ChunkHeightmap.resolution

    public let seed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let resolution: Int
    public let samples: [TerrainSample]

    public init(
        seed: WorldSeed,
        coordinate: ChunkCoordinate,
        resolution: Int = Self.defaultResolution,
        samples: [TerrainSample]
    ) {
        precondition(resolution > 1, "TerrainSampleGrid requires at least two samples per axis.")
        precondition(
            samples.count == resolution * resolution,
            "TerrainSampleGrid requires a square sample array matching its resolution."
        )

        self.seed = seed
        self.coordinate = coordinate
        self.resolution = resolution
        self.samples = samples
    }

    public subscript(localX: Int, localZ: Int) -> TerrainSample {
        sample(localX: localX, localZ: localZ)
    }

    public func sample(localX: Int, localZ: Int) -> TerrainSample {
        precondition(contains(localX: localX, localZ: localZ), "TerrainSampleGrid sample index out of bounds.")

        return samples[index(localX: localX, localZ: localZ)]
    }

    public func height(localX: Int, localZ: Int) -> Float {
        sample(localX: localX, localZ: localZ).height
    }

    public func contains(localX: Int, localZ: Int) -> Bool {
        (0..<resolution).contains(localX) && (0..<resolution).contains(localZ)
    }

    public var visibleSamples: [TerrainSample] {
        samples
    }

    public var validationReport: TerrainValidationReport {
        TerrainValidationReport(grid: self)
    }

    public var stableHash: UInt64 {
        var hasher = StableHash.Builder()
        hasher.combine(seed)
        hasher.combine(coordinate)
        hasher.combine(resolution)

        for sample in samples {
            sample.stableHash(into: &hasher)
        }

        return hasher.finalize().value
    }

    private func index(localX: Int, localZ: Int) -> Int {
        localZ * resolution + localX
    }
}
