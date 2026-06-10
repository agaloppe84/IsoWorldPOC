public enum BiomeType: String, CaseIterable, Codable, Sendable {
    case grassland
    case forest
    case rockyHighlands
    case dryPlateau
    case wetValley
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

public struct BiomeParameters: Equatable, Hashable, Codable, Sendable {
    public let heightOffset: Float
    public let ruggednessMultiplier: Float
    public let propDensityMultiplier: Float
    public let materialIdentifier: String
    public let placeholderColor: BiomeColor
    public let terrainMaterial: TerrainMaterialDescriptor

    public init(
        heightOffset: Float,
        ruggednessMultiplier: Float,
        propDensityMultiplier: Float,
        materialIdentifier: String,
        placeholderColor: BiomeColor,
        terrainMaterial: TerrainMaterialDescriptor
    ) {
        self.heightOffset = heightOffset
        self.ruggednessMultiplier = ruggednessMultiplier
        self.propDensityMultiplier = propDensityMultiplier
        self.materialIdentifier = materialIdentifier
        self.placeholderColor = placeholderColor
        self.terrainMaterial = terrainMaterial
    }
}

public struct Biome: Equatable, Hashable, Codable, Sendable {
    public let type: BiomeType
    public let parameters: BiomeParameters

    public var heightOffset: Float {
        parameters.heightOffset
    }

    public var ruggednessMultiplier: Float {
        parameters.ruggednessMultiplier
    }

    public var propDensityMultiplier: Float {
        parameters.propDensityMultiplier
    }

    public var materialIdentifier: String {
        parameters.materialIdentifier
    }

    public var placeholderColor: BiomeColor {
        parameters.placeholderColor
    }

    public var terrainMaterial: TerrainMaterialDescriptor {
        parameters.terrainMaterial
    }

    public init(
        type: BiomeType,
        heightOffset: Float,
        ruggednessMultiplier: Float,
        materialIdentifier: String,
        placeholderColor: BiomeColor
    ) {
        self.type = type
        self.parameters = BiomeParameters(
            heightOffset: heightOffset,
            ruggednessMultiplier: ruggednessMultiplier,
            propDensityMultiplier: 1,
            materialIdentifier: materialIdentifier,
            placeholderColor: placeholderColor,
            terrainMaterial: TerrainMaterialDescriptor(
                kind: .grass,
                identifier: materialIdentifier,
                baseColor: placeholderColor,
                roughness: 0.85
            )
        )
    }

    public init(type: BiomeType, parameters: BiomeParameters) {
        self.type = type
        self.parameters = parameters
    }

    public static func definition(for type: BiomeType) -> Biome {
        switch type {
        case .grassland:
            Biome(
                type: .grassland,
                parameters: BiomeParameters(
                    heightOffset: -0.10,
                    ruggednessMultiplier: 0.55,
                    propDensityMultiplier: 0.75,
                    materialIdentifier: "biome.grassland",
                    placeholderColor: BiomeColor(red: 0.33, green: 0.64, blue: 0.25),
                    terrainMaterial: .definition(for: .grass)
                )
            )
        case .forest:
            Biome(
                type: .forest,
                parameters: BiomeParameters(
                    heightOffset: 0.05,
                    ruggednessMultiplier: 0.75,
                    propDensityMultiplier: 1.35,
                    materialIdentifier: "biome.forest",
                    placeholderColor: BiomeColor(red: 0.10, green: 0.36, blue: 0.16),
                    terrainMaterial: .definition(for: .dirt)
                )
            )
        case .rockyHighlands:
            Biome(
                type: .rockyHighlands,
                parameters: BiomeParameters(
                    heightOffset: 0.55,
                    ruggednessMultiplier: 1.45,
                    propDensityMultiplier: 0.95,
                    materialIdentifier: "biome.rockyHighlands",
                    placeholderColor: BiomeColor(red: 0.45, green: 0.45, blue: 0.40),
                    terrainMaterial: .definition(for: .rock)
                )
            )
        case .dryPlateau:
            Biome(
                type: .dryPlateau,
                parameters: BiomeParameters(
                    heightOffset: 0.30,
                    ruggednessMultiplier: 0.95,
                    propDensityMultiplier: 0.45,
                    materialIdentifier: "biome.dryPlateau",
                    placeholderColor: BiomeColor(red: 0.62, green: 0.50, blue: 0.26),
                    terrainMaterial: .definition(for: .sand)
                )
            )
        case .wetValley:
            Biome(
                type: .wetValley,
                parameters: BiomeParameters(
                    heightOffset: -0.25,
                    ruggednessMultiplier: 0.45,
                    propDensityMultiplier: 1.10,
                    materialIdentifier: "biome.wetValley",
                    placeholderColor: BiomeColor(red: 0.18, green: 0.48, blue: 0.34),
                    terrainMaterial: .definition(for: .wetValley)
                )
            )
        }
    }
}
