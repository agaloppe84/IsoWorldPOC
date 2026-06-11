public struct EcotoneRule: Equatable, Hashable, Codable, Sendable {
    public let firstBiomeType: BiomeType
    public let secondBiomeType: BiomeType
    public let softnessMeters: Float
    public let edgePropBoost: Float
    public let materialBlendCurve: String

    public init(
        firstBiomeType: BiomeType,
        secondBiomeType: BiomeType,
        softnessMeters: Float,
        edgePropBoost: Float,
        materialBlendCurve: String = "smoothstep"
    ) {
        self.firstBiomeType = firstBiomeType
        self.secondBiomeType = secondBiomeType
        self.softnessMeters = max(softnessMeters, 0)
        self.edgePropBoost = min(max(edgePropBoost, 0), 1)
        self.materialBlendCurve = materialBlendCurve
    }

    public func matches(_ first: BiomeType, _ second: BiomeType) -> Bool {
        (firstBiomeType == first && secondBiomeType == second) ||
            (firstBiomeType == second && secondBiomeType == first)
    }

    public static let defaultRules: [EcotoneRule] = [
        EcotoneRule(firstBiomeType: .temperateForest, secondBiomeType: .grassland, softnessMeters: 180, edgePropBoost: 0.35),
        EcotoneRule(firstBiomeType: .grassland, secondBiomeType: .desert, softnessMeters: 220, edgePropBoost: 0.18),
        EcotoneRule(firstBiomeType: .temperateForest, secondBiomeType: .marsh, softnessMeters: 140, edgePropBoost: 0.42),
        EcotoneRule(firstBiomeType: .grassland, secondBiomeType: .marsh, softnessMeters: 160, edgePropBoost: 0.30),
    ]
}
