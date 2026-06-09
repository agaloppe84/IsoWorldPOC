public enum BiomeType: String, CaseIterable, Codable, Sendable {
    case plain
    case forest
    case rocky
    case highlands
}

public struct BiomeColor: Equatable, Hashable, Codable, Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct Biome: Equatable, Hashable, Codable, Sendable {
    public let type: BiomeType
    public let heightOffset: Float
    public let ruggednessMultiplier: Float
    public let materialIdentifier: String
    public let placeholderColor: BiomeColor

    public init(
        type: BiomeType,
        heightOffset: Float,
        ruggednessMultiplier: Float,
        materialIdentifier: String,
        placeholderColor: BiomeColor
    ) {
        self.type = type
        self.heightOffset = heightOffset
        self.ruggednessMultiplier = ruggednessMultiplier
        self.materialIdentifier = materialIdentifier
        self.placeholderColor = placeholderColor
    }

    public static func definition(for type: BiomeType) -> Biome {
        switch type {
        case .plain:
            Biome(
                type: .plain,
                heightOffset: -0.10,
                ruggednessMultiplier: 0.55,
                materialIdentifier: "biome.plain",
                placeholderColor: BiomeColor(red: 0.29, green: 0.58, blue: 0.25)
            )
        case .forest:
            Biome(
                type: .forest,
                heightOffset: 0.05,
                ruggednessMultiplier: 0.75,
                materialIdentifier: "biome.forest",
                placeholderColor: BiomeColor(red: 0.12, green: 0.38, blue: 0.18)
            )
        case .rocky:
            Biome(
                type: .rocky,
                heightOffset: 0.35,
                ruggednessMultiplier: 1.35,
                materialIdentifier: "biome.rocky",
                placeholderColor: BiomeColor(red: 0.42, green: 0.43, blue: 0.39)
            )
        case .highlands:
            Biome(
                type: .highlands,
                heightOffset: 0.75,
                ruggednessMultiplier: 1.05,
                materialIdentifier: "biome.highlands",
                placeholderColor: BiomeColor(red: 0.46, green: 0.50, blue: 0.27)
            )
        }
    }
}
