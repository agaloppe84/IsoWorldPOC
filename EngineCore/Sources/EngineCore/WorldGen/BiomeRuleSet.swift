public struct BiomeRuleSet: Equatable, Codable, Sendable {
    public init() {}

    public func biomeType(for climate: ClimateSample) -> BiomeType {
        if climate.elevation > 0.62 {
            return .rockyHighlands
        }

        if climate.elevation < -0.28 && climate.moisture > 0.15 {
            return .wetValley
        }

        if climate.moisture < -0.34 && climate.continentalness > 0.02 {
            return .dryPlateau
        }

        if climate.moisture > 0.12 && climate.temperature > -0.45 {
            return .forest
        }

        return .grassland
    }
}
