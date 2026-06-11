public struct SubBiomeDefinition: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let parentBiomeType: BiomeType
    public let displayName: String
    public let rarity: Float
    public let preferredSlope: ClosedRange<Float>
    public let preferredDistanceToWater: ClosedRange<Float>

    public init(
        identifier: String,
        parentBiomeType: BiomeType,
        displayName: String,
        rarity: Float,
        preferredSlope: ClosedRange<Float>,
        preferredDistanceToWater: ClosedRange<Float>
    ) {
        self.identifier = identifier
        self.parentBiomeType = parentBiomeType
        self.displayName = displayName
        self.rarity = min(max(rarity, 0), 1)
        self.preferredSlope = preferredSlope
        self.preferredDistanceToWater = preferredDistanceToWater
    }

    public static func defaults(for parentBiomeType: BiomeType) -> [SubBiomeDefinition] {
        [
            SubBiomeDefinition(
                identifier: "subbiome.\(parentBiomeType.rawValue).core",
                parentBiomeType: parentBiomeType,
                displayName: "\(Biome.definition(for: parentBiomeType).displayName) core",
                rarity: 1,
                preferredSlope: 0...0.45,
                preferredDistanceToWater: 0.15...1
            ),
            SubBiomeDefinition(
                identifier: "subbiome.\(parentBiomeType.rawValue).edge",
                parentBiomeType: parentBiomeType,
                displayName: "\(Biome.definition(for: parentBiomeType).displayName) edge",
                rarity: 0.45,
                preferredSlope: 0...0.85,
                preferredDistanceToWater: 0...0.55
            ),
        ]
    }
}
