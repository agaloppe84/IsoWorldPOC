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
}
