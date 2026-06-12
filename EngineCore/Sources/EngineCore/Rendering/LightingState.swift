public struct LightingState: Equatable, Codable, Sendable {
    public let sunDirection: PropVector3
    public let sunIntensity: Float
    public let ambientIntensity: Float
    public let shadowsEnabled: Bool

    public init(
        sunDirection: PropVector3,
        sunIntensity: Float,
        ambientIntensity: Float,
        shadowsEnabled: Bool
    ) {
        self.sunDirection = sunDirection
        self.sunIntensity = sunIntensity
        self.ambientIntensity = ambientIntensity
        self.shadowsEnabled = shadowsEnabled
    }

    public static let defaultDay = LightingState(
        sunDirection: PropVector3(x: -0.35, y: -0.85, z: -0.25),
        sunIntensity: 0.90,
        ambientIntensity: 0.38,
        shadowsEnabled: false
    )

    public static func daylight(renderDNA: WorldRenderDNA) -> LightingState {
        let warmth = min(max((renderDNA.lightTemperature - 4_800) / 2_000, 0), 1)
        let exposureCompensation = min(max(renderDNA.exposureBias, -0.20), 0.20)

        return LightingState(
            sunDirection: PropVector3(
                x: -0.38 + warmth * 0.06,
                y: -0.86,
                z: -0.22 - warmth * 0.08
            ),
            sunIntensity: 0.88 + exposureCompensation,
            ambientIntensity: 0.34 + max(renderDNA.fogDensityBias, 0) * 0.8,
            shadowsEnabled: false
        )
    }
}
