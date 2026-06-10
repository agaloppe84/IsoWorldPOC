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
    public let splat: TerrainMaterialSplat

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
        blendWeight: Float = 0,
        splat: TerrainMaterialSplat? = nil
    ) {
        let secondaryBiomeType = secondaryBiomeType ?? biomeType
        let secondaryMaterialKind = secondaryMaterialKind ?? materialKind
        let secondaryMaterialIdentifier = secondaryMaterialIdentifier ?? materialIdentifier
        let secondaryBaseColor = secondaryBaseColor ?? baseColor
        let secondaryRoughness = secondaryRoughness ?? roughness
        let blendWeight = Self.clampedBlendWeight(blendWeight)

        self.biomeType = biomeType
        self.materialKind = materialKind
        self.materialIdentifier = materialIdentifier
        self.baseColor = baseColor
        self.roughness = roughness
        self.secondaryBiomeType = secondaryBiomeType
        self.secondaryMaterialKind = secondaryMaterialKind
        self.secondaryMaterialIdentifier = secondaryMaterialIdentifier
        self.secondaryBaseColor = secondaryBaseColor
        self.secondaryRoughness = secondaryRoughness
        self.blendWeight = blendWeight
        self.splat = splat ?? TerrainMaterialSplat(layers: [
            TerrainMaterialSplatLayer(
                biomeType: biomeType,
                materialKind: materialKind,
                materialIdentifier: materialIdentifier,
                baseColor: baseColor,
                roughness: roughness,
                weight: 1 - blendWeight
            ),
            TerrainMaterialSplatLayer(
                biomeType: secondaryBiomeType,
                materialKind: secondaryMaterialKind,
                materialIdentifier: secondaryMaterialIdentifier,
                baseColor: secondaryBaseColor,
                roughness: secondaryRoughness,
                weight: blendWeight
            ),
        ])
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

    public init(
        primaryBiome: Biome,
        splat: TerrainMaterialSplat
    ) {
        let secondaryLayer = splat.layers.first { layer in
            layer.materialIdentifier != primaryBiome.terrainMaterial.identifier
        }
        let secondaryBiome = secondaryLayer.map { layer in
            Biome.definition(for: layer.biomeType)
        } ?? primaryBiome

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
            blendWeight: secondaryLayer?.weight ?? 0,
            splat: splat
        )
    }

    private static func clampedBlendWeight(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}
