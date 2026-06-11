public struct SurfaceState: Equatable, Hashable, Codable, Sendable {
    public let wetness: Float
    public let snow: Float
    public let dust: Float
    public let mud: Float

    public init(
        wetness: Float = 0,
        snow: Float = 0,
        dust: Float = 0,
        mud: Float = 0
    ) {
        self.wetness = Self.clamped01(wetness)
        self.snow = Self.clamped01(snow)
        self.dust = Self.clamped01(dust)
        self.mud = Self.clamped01(mud)
    }

    public static let dry = SurfaceState()

    public func applying(to parameters: MaterialParameterBlock) -> MaterialParameterBlock {
        let wetDarkening = 1 - wetness * 0.35
        let dustBrightening = 1 + dust * 0.12
        let snowBlend = snow
        let mudDarkening = 1 - mud * 0.20
        let baseColor = parameters.baseColor
        let adjustedColor = BiomeColor(
            red: mix(baseColor.red * wetDarkening * mudDarkening * dustBrightening, 0.88, snowBlend),
            green: mix(baseColor.green * wetDarkening * mudDarkening * dustBrightening, 0.92, snowBlend),
            blue: mix(baseColor.blue * wetDarkening * mudDarkening * dustBrightening, 0.90, snowBlend)
        )
        let wetRoughness = mix(parameters.roughness, 0.34, wetness)
        let snowyRoughness = mix(wetRoughness, 0.72, snow)
        let dustyRoughness = mix(snowyRoughness, 0.94, dust)

        return MaterialParameterBlock(
            baseColor: adjustedColor,
            normalIntensity: parameters.normalIntensity,
            metallic: parameters.metallic,
            roughness: dustyRoughness,
            ambientOcclusion: parameters.ambientOcclusion,
            emissiveStrength: parameters.emissiveStrength
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

private func mix(_ lhs: Float, _ rhs: Float, _ amount: Float) -> Float {
    lhs + (rhs - lhs) * min(max(amount, 0), 1)
}
