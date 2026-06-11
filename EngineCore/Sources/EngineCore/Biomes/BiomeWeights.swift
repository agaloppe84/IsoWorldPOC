import Foundation

public struct BiomeWeightLayer: Equatable, Hashable, Codable, Sendable {
    public let biomeType: BiomeType
    public let weight: Float

    public var biome: Biome {
        Biome.definition(for: biomeType)
    }

    public init(biomeType: BiomeType, weight: Float) {
        self.biomeType = biomeType
        self.weight = min(max(weight, 0), 1)
    }
}

public struct BiomeWeights: Equatable, Hashable, Codable, Sendable {
    public let layers: [BiomeWeightLayer]

    public var primaryLayer: BiomeWeightLayer {
        layers[0]
    }

    public var secondaryLayer: BiomeWeightLayer? {
        layers.dropFirst().first
    }

    public var primaryBiomeType: BiomeType {
        primaryLayer.biomeType
    }

    public var secondaryBiomeType: BiomeType {
        secondaryLayer?.biomeType ?? primaryBiomeType
    }

    public var primaryWeight: Float {
        primaryLayer.weight
    }

    public var secondaryWeight: Float {
        secondaryLayer?.weight ?? 0
    }

    public var totalWeight: Float {
        layers.reduce(0) { $0 + $1.weight }
    }

    public var isNormalized: Bool {
        abs(totalWeight - 1) <= 0.0001
    }

    public init(primary: BiomeType, secondary: BiomeType? = nil, secondaryWeight: Float = 0) {
        let clampedSecondaryWeight = min(max(secondaryWeight, 0), 1)
        var layers = [
            BiomeWeightLayer(
                biomeType: primary,
                weight: 1 - clampedSecondaryWeight
            )
        ]

        if let secondary, secondary != primary, clampedSecondaryWeight > 0 {
            layers.append(BiomeWeightLayer(
                biomeType: secondary,
                weight: clampedSecondaryWeight
            ))
        }

        self.init(layers: layers)
    }

    public init(scores: [(BiomeType, Float)], exponent: Float = 1) {
        let positiveScores = scores.compactMap { type, score -> (BiomeType, Float)? in
            guard score > 0 else {
                return nil
            }

            return (
                type,
                Float(pow(Double(score), Double(max(0.25, exponent))))
            )
        }

        guard !positiveScores.isEmpty else {
            self.init(primary: .grassland)
            return
        }

        let sortedScores = positiveScores.sorted { lhs, rhs in
            if abs(lhs.1 - rhs.1) <= 0.0001 {
                return lhs.0.rawValue < rhs.0.rawValue
            }

            return lhs.1 > rhs.1
        }
        let topScores = Array(sortedScores.prefix(2))
        let totalScore = topScores.reduce(Float(0)) { $0 + $1.1 }
        let layers = topScores.map { type, score in
            BiomeWeightLayer(
                biomeType: type,
                weight: score / totalScore
            )
        }

        self.init(layers: layers)
    }

    public init(layers: [BiomeWeightLayer]) {
        precondition(!layers.isEmpty, "BiomeWeights requires at least one layer.")

        let merged = layers.reduce(into: [BiomeType: Float]()) { partialResult, layer in
            partialResult[layer.biomeType, default: 0] += layer.weight
        }
        let sortedLayers = merged
            .map { BiomeWeightLayer(biomeType: $0.key, weight: $0.value) }
            .sorted { lhs, rhs in
                if abs(lhs.weight - rhs.weight) <= 0.0001 {
                    return lhs.biomeType.rawValue < rhs.biomeType.rawValue
                }

                return lhs.weight > rhs.weight
            }
        let topLayers = Array(sortedLayers.prefix(2))
        let totalWeight = topLayers.reduce(Float(0)) { $0 + $1.weight }

        guard totalWeight > 0 else {
            self.layers = [BiomeWeightLayer(biomeType: layers[0].biomeType, weight: 1)]
            return
        }

        self.layers = topLayers.map { layer in
            BiomeWeightLayer(
                biomeType: layer.biomeType,
                weight: layer.weight / totalWeight
            )
        }
    }
}
