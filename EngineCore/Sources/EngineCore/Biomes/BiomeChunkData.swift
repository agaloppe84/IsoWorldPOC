public struct BiomeChunkSample: Equatable, Hashable, Codable, Sendable {
    public let localX: Int
    public let localZ: Int
    public let worldX: Int
    public let worldZ: Int
    public let climate: ClimateSample
    public let weights: BiomeWeights
    public let ecotoneRule: EcotoneRule?

    public var primaryBiomeType: BiomeType {
        weights.primaryBiomeType
    }

    public var secondaryBiomeType: BiomeType {
        weights.secondaryBiomeType
    }

    public var isEcotone: Bool {
        weights.secondaryWeight >= 0.10
    }
}

public struct BiomeChunkData: Equatable, Hashable, Codable, Sendable {
    public let seed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let resolution: Int
    public let samples: [BiomeChunkSample]

    public var dominantBiomeCoverage: [BiomeType: Float] {
        guard !samples.isEmpty else {
            return [:]
        }

        var coverage: [BiomeType: Float] = [:]

        for sample in samples {
            for layer in sample.weights.layers {
                coverage[layer.biomeType, default: 0] += layer.weight
            }
        }

        let sampleCount = Float(samples.count)
        return coverage.mapValues { $0 / sampleCount }
    }

    public init(
        seed: WorldSeed,
        coordinate: ChunkCoordinate,
        resolution: Int,
        samples: [BiomeChunkSample]
    ) {
        precondition(resolution > 0, "BiomeChunkData resolution must be positive.")
        precondition(samples.count == resolution * resolution, "BiomeChunkData sample count must match resolution squared.")

        self.seed = seed
        self.coordinate = coordinate
        self.resolution = resolution
        self.samples = samples
    }

    public subscript(localX: Int, localZ: Int) -> BiomeChunkSample {
        samples[localZ * resolution + localX]
    }

    public func stableHash() -> StableHash {
        StableHash.make { builder in
            builder.combine(seed)
            builder.combine(coordinate)
            builder.combine(resolution)

            for sample in samples {
                builder.combine(sample.worldX)
                builder.combine(sample.worldZ)
                builder.combine(sample.primaryBiomeType.rawValue)
                builder.combine(sample.secondaryBiomeType.rawValue)
                builder.combine(Int((sample.weights.primaryWeight * 10_000).rounded()))
                builder.combine(Int((sample.weights.secondaryWeight * 10_000).rounded()))
            }
        }
    }
}
