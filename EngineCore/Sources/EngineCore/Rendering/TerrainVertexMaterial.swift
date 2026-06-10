public struct TerrainVertexMaterial: Equatable, Hashable, Codable, Sendable {
    public let biomeType: BiomeType
    public let materialKind: TerrainMaterialKind
    public let materialIdentifier: String
    public let baseColor: BiomeColor
    public let roughness: Float
    public let secondaryBiomeType: BiomeType
    public let secondaryMaterialKind: TerrainMaterialKind
    public let secondaryMaterialIdentifier: String
    public let secondaryBaseColor: BiomeColor
    public let secondaryRoughness: Float
    public let blendWeight: Float

    public var primaryWeight: Float {
        1.0 - blendWeight
    }

    public var secondaryWeight: Float {
        blendWeight
    }

    public var hasBlend: Bool {
        blendWeight > 0 && materialIdentifier != secondaryMaterialIdentifier
    }

    public var blendedBaseColor: BiomeColor {
        BiomeColor(
            red: lerp(baseColor.red, secondaryBaseColor.red, blendWeight),
            green: lerp(baseColor.green, secondaryBaseColor.green, blendWeight),
            blue: lerp(baseColor.blue, secondaryBaseColor.blue, blendWeight)
        )
    }

    public var blendedRoughness: Float {
        lerp(roughness, secondaryRoughness, blendWeight)
    }

    public init(
        biomeType: BiomeType,
        materialKind: TerrainMaterialKind,
        materialIdentifier: String,
        baseColor: BiomeColor,
        roughness: Float,
        secondaryBiomeType: BiomeType? = nil,
        secondaryMaterialKind: TerrainMaterialKind? = nil,
        secondaryMaterialIdentifier: String? = nil,
        secondaryBaseColor: BiomeColor? = nil,
        secondaryRoughness: Float? = nil,
        blendWeight: Float = 0
    ) {
        self.biomeType = biomeType
        self.materialKind = materialKind
        self.materialIdentifier = materialIdentifier
        self.baseColor = baseColor
        self.roughness = roughness
        self.secondaryBiomeType = secondaryBiomeType ?? biomeType
        self.secondaryMaterialKind = secondaryMaterialKind ?? materialKind
        self.secondaryMaterialIdentifier = secondaryMaterialIdentifier ?? materialIdentifier
        self.secondaryBaseColor = secondaryBaseColor ?? baseColor
        self.secondaryRoughness = secondaryRoughness ?? roughness
        self.blendWeight = Self.clampedBlendWeight(blendWeight)
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

    public init(
        primaryBiome: Biome,
        secondaryBiome: Biome?,
        blendWeight: Float
    ) {
        let secondaryBiome = secondaryBiome ?? primaryBiome

        self.init(
            biomeType: primaryBiome.type,
            materialKind: primaryBiome.terrainMaterial.kind,
            materialIdentifier: primaryBiome.terrainMaterial.identifier,
            baseColor: primaryBiome.terrainMaterial.baseColor,
            roughness: primaryBiome.terrainMaterial.roughness,
            secondaryBiomeType: secondaryBiome.type,
            secondaryMaterialKind: secondaryBiome.terrainMaterial.kind,
            secondaryMaterialIdentifier: secondaryBiome.terrainMaterial.identifier,
            secondaryBaseColor: secondaryBiome.terrainMaterial.baseColor,
            secondaryRoughness: secondaryBiome.terrainMaterial.roughness,
            blendWeight: secondaryBiome.type == primaryBiome.type ? 0 : blendWeight
        )
    }

    private static func clampedBlendWeight(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}
