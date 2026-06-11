public struct PropChunkData: Equatable, Codable, Sendable {
    public let coordinate: ChunkCoordinate
    public let biome: Biome
    public let recipes: [PropRecipe]
    public let variants: [PropVariant]

    public init(
        coordinate: ChunkCoordinate,
        biome: Biome,
        recipes: [PropRecipe],
        variants: [PropVariant]
    ) {
        precondition(recipes.count == variants.count, "PropChunkData requires one variant per recipe.")

        self.coordinate = coordinate
        self.biome = biome
        self.recipes = recipes
        self.variants = variants
    }

    public var placements: [PropPlacement] {
        recipes.map(\.placement)
    }
}
