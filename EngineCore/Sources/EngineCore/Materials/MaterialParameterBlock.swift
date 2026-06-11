public struct MaterialParameterBlock: Equatable, Hashable, Codable, Sendable {
    public let baseColor: BiomeColor
    public let normalIntensity: Float
    public let metallic: Float
    public let roughness: Float
    public let ambientOcclusion: Float
    public let emissiveStrength: Float

    public init(
        baseColor: BiomeColor,
        normalIntensity: Float = 1,
        metallic: Float = 0,
        roughness: Float,
        ambientOcclusion: Float = 1,
        emissiveStrength: Float = 0
    ) {
        self.baseColor = baseColor
        self.normalIntensity = Self.clamped01(normalIntensity)
        self.metallic = Self.clamped01(metallic)
        self.roughness = Self.clamped01(roughness)
        self.ambientOcclusion = Self.clamped01(ambientOcclusion)
        self.emissiveStrength = max(emissiveStrength, 0)
    }

    public static func terrain(_ material: TerrainMaterialDescriptor) -> MaterialParameterBlock {
        MaterialParameterBlock(
            baseColor: material.baseColor,
            roughness: material.roughness
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
