public struct PropRecipe: Equatable, Hashable, Codable, Sendable {
    public let stableID: StableID
    public let placement: PropPlacement
    public let biomeType: BiomeType
    public let archetypeID: String
    public let context: PropContext
    public let genome: PropVariantGenome

    public init(
        stableID: StableID,
        placement: PropPlacement,
        biomeType: BiomeType,
        archetypeID: String,
        context: PropContext,
        genome: PropVariantGenome
    ) {
        self.stableID = stableID
        self.placement = placement
        self.biomeType = biomeType
        self.archetypeID = archetypeID
        self.context = context
        self.genome = genome
    }
}
