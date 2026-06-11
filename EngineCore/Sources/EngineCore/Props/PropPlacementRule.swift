public struct PropValueRange: Equatable, Hashable, Codable, Sendable {
    public let minimum: Float
    public let maximum: Float

    public init(_ minimum: Float, _ maximum: Float) {
        precondition(maximum >= minimum, "PropValueRange maximum must be >= minimum.")

        self.minimum = minimum
        self.maximum = maximum
    }

    public func contains(_ value: Float) -> Bool {
        minimum...maximum ~= value
    }
}

public struct PropPlacementRule: Equatable, Hashable, Codable, Sendable {
    public let type: PropType
    public let baseWeight: Float
    public let biomeWeights: [BiomeType: Float]
    public let slopeRange: PropValueRange
    public let moistureRange: PropValueRange
    public let walkabilityRange: PropValueRange

    public init(
        type: PropType,
        baseWeight: Float,
        biomeWeights: [BiomeType: Float],
        slopeRange: PropValueRange = PropValueRange(0, 10),
        moistureRange: PropValueRange = PropValueRange(0, 1),
        walkabilityRange: PropValueRange = PropValueRange(0, 1)
    ) {
        precondition(baseWeight >= 0, "PropPlacementRule baseWeight must be non-negative.")

        self.type = type
        self.baseWeight = baseWeight
        self.biomeWeights = biomeWeights
        self.slopeRange = slopeRange
        self.moistureRange = moistureRange
        self.walkabilityRange = walkabilityRange
    }

    public func score(in context: PropContext) -> Float {
        guard
            baseWeight > 0,
            let biomeWeight = biomeWeights[context.biome.type],
            biomeWeight > 0,
            slopeRange.contains(context.slope),
            moistureRange.contains(context.moisture),
            walkabilityRange.contains(context.walkability)
        else {
            return 0
        }

        return baseWeight * biomeWeight
    }
}
