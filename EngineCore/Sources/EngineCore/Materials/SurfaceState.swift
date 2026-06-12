public struct SurfaceState: Equatable, Hashable, Codable, Sendable {
    public let wetness: Float
    public let snow: Float
    public let dust: Float
    public let mud: Float
    public let moss: Float

    public init(
        wetness: Float = 0,
        snow: Float = 0,
        dust: Float = 0,
        mud: Float = 0,
        moss: Float = 0
    ) {
        self.wetness = Self.clamped01(wetness)
        self.snow = Self.clamped01(snow)
        self.dust = Self.clamped01(dust)
        self.mud = Self.clamped01(mud)
        self.moss = Self.clamped01(moss)
    }

    public static let dry = SurfaceState()

    public func applying(to parameters: MaterialParameterBlock) -> MaterialParameterBlock {
        let wetness = self.wetness * parameters.wetnessResponse
        let snow = self.snow * parameters.snowResponse
        let dust = self.dust * parameters.dustResponse
        let moss = self.moss * parameters.mossResponse
        let wetDarkening = 1 - wetness * 0.35
        let dustBrightening = 1 + dust * 0.12
        let snowBlend = snow
        let mudDarkening = 1 - mud * 0.20
        let baseColor = parameters.baseColor
        let weatheredColor = BiomeColor(
            red: mix(baseColor.red * wetDarkening * mudDarkening * dustBrightening, 0.88, snowBlend),
            green: mix(baseColor.green * wetDarkening * mudDarkening * dustBrightening, 0.92, snowBlend),
            blue: mix(baseColor.blue * wetDarkening * mudDarkening * dustBrightening, 0.90, snowBlend)
        )
        let adjustedColor = BiomeColor(
            red: mix(weatheredColor.red, 0.16, moss),
            green: mix(weatheredColor.green, 0.34, moss),
            blue: mix(weatheredColor.blue, 0.19, moss)
        )
        let wetRoughness = mix(parameters.roughness, 0.34, wetness)
        let snowyRoughness = mix(wetRoughness, 0.72, snow)
        let dustyRoughness = mix(snowyRoughness, 0.94, dust)
        let mossyRoughness = mix(dustyRoughness, 0.86, moss)

        return MaterialParameterBlock(
            baseColor: adjustedColor,
            normalIntensity: parameters.normalIntensity,
            metallic: parameters.metallic,
            roughness: mossyRoughness,
            ambientOcclusion: parameters.ambientOcclusion,
            emissiveStrength: parameters.emissiveStrength,
            wetnessResponse: parameters.wetnessResponse,
            snowResponse: parameters.snowResponse,
            dustResponse: parameters.dustResponse,
            mossResponse: parameters.mossResponse
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case wetness
        case snow
        case dust
        case mud
        case moss
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            wetness: try container.decodeIfPresent(Float.self, forKey: .wetness) ?? 0,
            snow: try container.decodeIfPresent(Float.self, forKey: .snow) ?? 0,
            dust: try container.decodeIfPresent(Float.self, forKey: .dust) ?? 0,
            mud: try container.decodeIfPresent(Float.self, forKey: .mud) ?? 0,
            moss: try container.decodeIfPresent(Float.self, forKey: .moss) ?? 0
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(wetness, forKey: .wetness)
        try container.encode(snow, forKey: .snow)
        try container.encode(dust, forKey: .dust)
        try container.encode(mud, forKey: .mud)
        try container.encode(moss, forKey: .moss)
    }
}

private func mix(_ lhs: Float, _ rhs: Float, _ amount: Float) -> Float {
    lhs + (rhs - lhs) * min(max(amount, 0), 1)
}
