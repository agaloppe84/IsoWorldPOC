public struct BiomeRuleSet: Equatable, Codable, Sendable {
    public let transitionSharpness: Float

    public init() {
        self.transitionSharpness = 1
    }

    public init(transitionSharpness: Float) {
        self.transitionSharpness = max(0.25, transitionSharpness)
    }

    public func biomeType(for climate: ClimateSample) -> BiomeType {
        biomeWeights(for: climate).primaryBiomeType
    }

    public func biomeWeights(for climate: ClimateSample) -> BiomeWeights {
        var scores: [(BiomeType, Float)] = []

        scores.append((.freshwater, freshwaterScore(for: climate)))
        scores.append((.coast, coastScore(for: climate)))
        scores.append((.mountain, mountainScore(for: climate)))
        scores.append((.marsh, marshScore(for: climate)))
        scores.append((.taiga, taigaScore(for: climate)))
        scores.append((.desert, desertScore(for: climate)))
        scores.append((.temperateForest, forestScore(for: climate)))
        scores.append((.grassland, grasslandScore(for: climate)))

        return BiomeWeights(
            scores: scores,
            exponent: transitionSharpness
        )
    }

    private func freshwaterScore(for climate: ClimateSample) -> Float {
        let water = 1 - smoothStep(edge0: 0.04, edge1: 0.18, climate.distanceToWater)
        let low = 1 - smoothStep(edge0: 0.12, edge1: 0.42, climate.altitude)
        return water * low * 3.0
    }

    private func coastScore(for climate: ClimateSample) -> Float {
        let oceanEdge = smoothStep(edge0: -0.35, edge1: -0.70, climate.continentalness)
        let low = 1 - smoothStep(edge0: 0.15, edge1: 0.50, abs(climate.altitude))
        let nearWater = 1 - smoothStep(edge0: 0.18, edge1: 0.52, climate.distanceToWater)
        return oceanEdge * max(low, nearWater * 0.75) * 1.85
    }

    private func mountainScore(for climate: ClimateSample) -> Float {
        let elevation = smoothStep(edge0: 0.52, edge1: 0.78, climate.elevation)
        let altitude = smoothStep(edge0: 0.46, edge1: 0.72, climate.altitude)
        let steep = smoothStep(edge0: 0.32, edge1: 0.72, climate.slope)
        return max(max(elevation, altitude), steep) * 2.0
    }

    private func marshScore(for climate: ClimateSample) -> Float {
        let wet = smoothStep(edge0: 0.15, edge1: 0.52, climate.moisture)
        let low = 1 - smoothStep(edge0: 0.12, edge1: 0.45, climate.altitude)
        let waterInfluence = 1 - smoothStep(edge0: 0.25, edge1: 0.70, climate.distanceToWater)
        return wet * max(low, waterInfluence * 0.80) * 2.25
    }

    private func taigaScore(for climate: ClimateSample) -> Float {
        let cold = 1 - smoothStep(edge0: -0.48, edge1: -0.14, climate.temperature)
        let notTooDry = smoothStep(edge0: -0.40, edge1: 0.10, climate.moisture)
        let notPeak = 1 - smoothStep(edge0: 0.54, edge1: 0.86, climate.altitude)
        return cold * notTooDry * notPeak * 1.45
    }

    private func desertScore(for climate: ClimateSample) -> Float {
        let dry = 1 - smoothStep(edge0: -0.52, edge1: -0.20, climate.moisture)
        let warm = smoothStep(edge0: -0.10, edge1: 0.42, climate.temperature)
        let inland = smoothStep(edge0: -0.12, edge1: 0.28, climate.continentalness)
        return dry * max(warm, inland * 0.75) * 1.50
    }

    private func forestScore(for climate: ClimateSample) -> Float {
        let wet = smoothStep(edge0: 0.04, edge1: 0.34, climate.moisture)
        let notFrozen = smoothStep(edge0: -0.55, edge1: -0.16, climate.temperature)
        let notHotDesert = 1 - smoothStep(edge0: 0.65, edge1: 0.95, climate.temperature)
        let notMountain = 1 - smoothStep(edge0: 0.48, edge1: 0.78, climate.altitude)
        return wet * notFrozen * notHotDesert * notMountain * 1.20
    }

    private func grasslandScore(for climate: ClimateSample) -> Float {
        let openMoisture = 1 - abs(climate.moisture + 0.08)
        let temperate = 1 - abs(climate.temperature - 0.08) * 0.55
        let lowMid = 1 - smoothStep(edge0: 0.45, edge1: 0.75, climate.altitude)
        return max(0.12, openMoisture * temperate * lowMid * 1.05)
    }

    private func smoothStep(edge0: Float, edge1: Float, _ value: Float) -> Float {
        guard edge0 != edge1 else {
            return value < edge0 ? 0 : 1
        }

        let amount = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return amount * amount * (3 - 2 * amount)
    }
}
