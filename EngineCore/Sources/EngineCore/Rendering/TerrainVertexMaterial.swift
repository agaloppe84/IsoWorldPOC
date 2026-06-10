public struct TerrainVertexMaterial: Equatable, Hashable, Codable, Sendable {
    public let biomeType: BiomeType
    public let materialKind: TerrainMaterialKind
    public let materialIdentifier: String
    public let baseColor: BiomeColor
    public let roughness: Float

    public init(
        biomeType: BiomeType,
        materialKind: TerrainMaterialKind,
        materialIdentifier: String,
        baseColor: BiomeColor,
        roughness: Float
    ) {
        self.biomeType = biomeType
        self.materialKind = materialKind
        self.materialIdentifier = materialIdentifier
        self.baseColor = baseColor
        self.roughness = roughness
    }

    public init(biome: Biome) {
        self.init(
            biomeType: biome.type,
            materialKind: biome.terrainMaterial.kind,
            materialIdentifier: biome.terrainMaterial.identifier,
            baseColor: biome.terrainMaterial.baseColor,
            roughness: biome.terrainMaterial.roughness
        )
    }
}
