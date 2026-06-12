public struct MaterialParameterBlock: Equatable, Hashable, Codable, Sendable {
    public let baseColor: BiomeColor
    public let normalIntensity: Float
    public let metallic: Float
    public let roughness: Float
    public let ambientOcclusion: Float
    public let emissiveStrength: Float
    public let wetnessResponse: Float
    public let snowResponse: Float
    public let dustResponse: Float
    public let mossResponse: Float

    public init(
        baseColor: BiomeColor,
        normalIntensity: Float = 1,
        metallic: Float = 0,
        roughness: Float,
        ambientOcclusion: Float = 1,
        emissiveStrength: Float = 0,
        wetnessResponse: Float = 1,
        snowResponse: Float = 1,
        dustResponse: Float = 1,
        mossResponse: Float = 1
    ) {
        self.baseColor = baseColor
        self.normalIntensity = Self.clamped01(normalIntensity)
        self.metallic = Self.clamped01(metallic)
        self.roughness = Self.clamped01(roughness)
        self.ambientOcclusion = Self.clamped01(ambientOcclusion)
        self.emissiveStrength = max(emissiveStrength, 0)
        self.wetnessResponse = Self.clamped01(wetnessResponse)
        self.snowResponse = Self.clamped01(snowResponse)
        self.dustResponse = Self.clamped01(dustResponse)
        self.mossResponse = Self.clamped01(mossResponse)
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

    private enum CodingKeys: String, CodingKey {
        case baseColor
        case normalIntensity
        case metallic
        case roughness
        case ambientOcclusion
        case emissiveStrength
        case wetnessResponse
        case snowResponse
        case dustResponse
        case mossResponse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            baseColor: try container.decode(BiomeColor.self, forKey: .baseColor),
            normalIntensity: try container.decodeIfPresent(Float.self, forKey: .normalIntensity) ?? 1,
            metallic: try container.decodeIfPresent(Float.self, forKey: .metallic) ?? 0,
            roughness: try container.decode(Float.self, forKey: .roughness),
            ambientOcclusion: try container.decodeIfPresent(Float.self, forKey: .ambientOcclusion) ?? 1,
            emissiveStrength: try container.decodeIfPresent(Float.self, forKey: .emissiveStrength) ?? 0,
            wetnessResponse: try container.decodeIfPresent(Float.self, forKey: .wetnessResponse) ?? 1,
            snowResponse: try container.decodeIfPresent(Float.self, forKey: .snowResponse) ?? 1,
            dustResponse: try container.decodeIfPresent(Float.self, forKey: .dustResponse) ?? 1,
            mossResponse: try container.decodeIfPresent(Float.self, forKey: .mossResponse) ?? 1
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(baseColor, forKey: .baseColor)
        try container.encode(normalIntensity, forKey: .normalIntensity)
        try container.encode(metallic, forKey: .metallic)
        try container.encode(roughness, forKey: .roughness)
        try container.encode(ambientOcclusion, forKey: .ambientOcclusion)
        try container.encode(emissiveStrength, forKey: .emissiveStrength)
        try container.encode(wetnessResponse, forKey: .wetnessResponse)
        try container.encode(snowResponse, forKey: .snowResponse)
        try container.encode(dustResponse, forKey: .dustResponse)
        try container.encode(mossResponse, forKey: .mossResponse)
    }
}
