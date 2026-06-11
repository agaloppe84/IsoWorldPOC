public struct PropCatalog: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let rules: [PropPlacementRule]

    public init(identifier: String, rules: [PropPlacementRule]) {
        precondition(!identifier.isEmpty, "PropCatalog identifier cannot be empty.")

        self.identifier = identifier
        self.rules = rules
    }

    public var supportedTypes: [PropType] {
        Array(Set(rules.map(\.type))).sorted { $0.rawValue < $1.rawValue }
    }

    public func chooseType(
        in context: PropContext,
        random: inout StableRNG
    ) -> PropType? {
        let weightedRules = rules.compactMap { rule -> (type: PropType, score: Float)? in
            let score = rule.score(in: context)

            guard score > 0 else {
                return nil
            }

            return (rule.type, score)
        }
        let totalScore = weightedRules.reduce(Float(0)) { $0 + $1.score }

        guard totalScore > 0 else {
            return nil
        }

        var roll = random.nextUnitFloat() * totalScore

        for weightedRule in weightedRules {
            roll -= weightedRule.score

            if roll <= 0 {
                return weightedRule.type
            }
        }

        return weightedRules.last?.type
    }

    public static let naturalV1 = PropCatalog(
        identifier: "prop.catalog.natural.v1",
        rules: [
            PropPlacementRule(
                type: .rock,
                baseWeight: 0.90,
                biomeWeights: [
                    .grassland: 0.65,
                    .temperateForest: 0.45,
                    .desert: 0.85,
                    .mountain: 1.25,
                    .marsh: 0.35,
                    .taiga: 0.70,
                    .coast: 1.10,
                    .freshwater: 0.45,
                ],
                slopeRange: PropValueRange(0.04, 2.40),
                walkabilityRange: PropValueRange(0.05, 1)
            ),
            PropPlacementRule(
                type: .pebble,
                baseWeight: 1.15,
                biomeWeights: [
                    .grassland: 0.75,
                    .temperateForest: 0.50,
                    .desert: 1.15,
                    .mountain: 1.10,
                    .marsh: 0.35,
                    .taiga: 0.65,
                    .coast: 1.35,
                    .freshwater: 0.80,
                ],
                slopeRange: PropValueRange(0, 1.70),
                walkabilityRange: PropValueRange(0.20, 1)
            ),
            PropPlacementRule(
                type: .grass,
                baseWeight: 1.40,
                biomeWeights: [
                    .grassland: 1.40,
                    .temperateForest: 1.00,
                    .desert: 0.08,
                    .mountain: 0.22,
                    .marsh: 1.20,
                    .taiga: 0.75,
                    .coast: 0.55,
                    .freshwater: 0.85,
                ],
                slopeRange: PropValueRange(0, 0.68),
                moistureRange: PropValueRange(0.18, 1),
                walkabilityRange: PropValueRange(0.42, 1)
            ),
            PropPlacementRule(
                type: .tree,
                baseWeight: 0.85,
                biomeWeights: [
                    .grassland: 0.28,
                    .temperateForest: 1.35,
                    .desert: 0.08,
                    .mountain: 0.12,
                    .marsh: 0.72,
                    .taiga: 1.10,
                    .coast: 0.26,
                    .freshwater: 0.70,
                ],
                slopeRange: PropValueRange(0, 0.56),
                moistureRange: PropValueRange(0.22, 1),
                walkabilityRange: PropValueRange(0.48, 1)
            ),
            PropPlacementRule(
                type: .deadwood,
                baseWeight: 0.55,
                biomeWeights: [
                    .grassland: 0.25,
                    .temperateForest: 1.00,
                    .desert: 0.12,
                    .mountain: 0.20,
                    .marsh: 0.95,
                    .taiga: 0.90,
                    .coast: 0.45,
                    .freshwater: 0.72,
                ],
                slopeRange: PropValueRange(0, 0.82),
                moistureRange: PropValueRange(0.16, 1),
                walkabilityRange: PropValueRange(0.32, 1)
            ),
            PropPlacementRule(
                type: .crystal,
                baseWeight: 0.22,
                biomeWeights: [
                    .grassland: 0.08,
                    .temperateForest: 0.05,
                    .desert: 0.35,
                    .mountain: 0.85,
                    .marsh: 0.40,
                    .taiga: 0.15,
                    .coast: 0.22,
                    .freshwater: 0.45,
                ],
                slopeRange: PropValueRange(0.10, 2.80),
                walkabilityRange: PropValueRange(0.05, 1)
            ),
        ]
    )
}
