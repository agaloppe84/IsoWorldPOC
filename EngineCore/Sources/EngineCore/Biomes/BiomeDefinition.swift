public enum BiomeType: String, CaseIterable, Codable, Sendable {
    case temperateForest
    case grassland
    case desert
    case mountain
    case marsh
    case taiga
    case coast
    case freshwater

    public static var forest: BiomeType { .temperateForest }
    public static var rockyHighlands: BiomeType { .mountain }
    public static var dryPlateau: BiomeType { .desert }
    public static var wetValley: BiomeType { .marsh }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "forest":
            self = .temperateForest
        case "rockyHighlands":
            self = .mountain
        case "dryPlateau":
            self = .desert
        case "wetValley":
            self = .marsh
        default:
            guard let value = BiomeType(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown biome type '\(rawValue)'."
                )
            }

            self = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
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
    public let displayName: String
    public let heightOffset: Float
    public let ruggednessMultiplier: Float
    public let propDensityMultiplier: Float
    public let materialIdentifier: String
    public let placeholderColor: BiomeColor
    public let terrainMaterial: TerrainMaterialDescriptor
    public let preferredTemperature: ClosedRange<Float>
    public let preferredHumidity: ClosedRange<Float>
    public let preferredAltitude: ClosedRange<Float>

    public init(
        displayName: String,
        heightOffset: Float,
        ruggednessMultiplier: Float,
        propDensityMultiplier: Float,
        materialIdentifier: String,
        placeholderColor: BiomeColor,
        terrainMaterial: TerrainMaterialDescriptor,
        preferredTemperature: ClosedRange<Float>,
        preferredHumidity: ClosedRange<Float>,
        preferredAltitude: ClosedRange<Float>
    ) {
        self.displayName = displayName
        self.heightOffset = heightOffset
        self.ruggednessMultiplier = ruggednessMultiplier
        self.propDensityMultiplier = propDensityMultiplier
        self.materialIdentifier = materialIdentifier
        self.placeholderColor = placeholderColor
        self.terrainMaterial = terrainMaterial
        self.preferredTemperature = preferredTemperature
        self.preferredHumidity = preferredHumidity
        self.preferredAltitude = preferredAltitude
    }
}

public struct Biome: Equatable, Hashable, Codable, Sendable {
    public let type: BiomeType
    public let parameters: BiomeParameters

    public var heightOffset: Float {
        parameters.heightOffset
    }

    public var displayName: String {
        parameters.displayName
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
            displayName: type.rawValue,
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
            ),
            preferredTemperature: -1...1,
            preferredHumidity: -1...1,
            preferredAltitude: -1...1
        )
    }

    public init(type: BiomeType, parameters: BiomeParameters) {
        self.type = type
        self.parameters = parameters
    }

    public static func definition(for type: BiomeType) -> Biome {
        switch type {
        case .temperateForest:
            Biome(
                type: .temperateForest,
                parameters: BiomeParameters(
                    displayName: "Temperate forest",
                    heightOffset: 0.05,
                    ruggednessMultiplier: 0.75,
                    propDensityMultiplier: 1.35,
                    materialIdentifier: "biome.temperateForest",
                    placeholderColor: BiomeColor(red: 0.10, green: 0.36, blue: 0.16),
                    terrainMaterial: .definition(for: .dirt),
                    preferredTemperature: -0.35...0.65,
                    preferredHumidity: 0.10...0.80,
                    preferredAltitude: -0.35...0.45
                )
            )
        case .grassland:
            Biome(
                type: .grassland,
                parameters: BiomeParameters(
                    displayName: "Grassland",
                    heightOffset: -0.10,
                    ruggednessMultiplier: 0.55,
                    propDensityMultiplier: 0.75,
                    materialIdentifier: "biome.grassland",
                    placeholderColor: BiomeColor(red: 0.33, green: 0.64, blue: 0.25),
                    terrainMaterial: .definition(for: .grass),
                    preferredTemperature: -0.15...0.75,
                    preferredHumidity: -0.25...0.35,
                    preferredAltitude: -0.35...0.35
                )
            )
        case .desert:
            Biome(
                type: .desert,
                parameters: BiomeParameters(
                    displayName: "Desert",
                    heightOffset: 0.30,
                    ruggednessMultiplier: 0.95,
                    propDensityMultiplier: 0.45,
                    materialIdentifier: "biome.desert",
                    placeholderColor: BiomeColor(red: 0.62, green: 0.50, blue: 0.26),
                    terrainMaterial: .definition(for: .sand),
                    preferredTemperature: 0.10...1.0,
                    preferredHumidity: -1.0 ... -0.25,
                    preferredAltitude: -0.15...0.55
                )
            )
        case .mountain:
            Biome(
                type: .mountain,
                parameters: BiomeParameters(
                    displayName: "Mountain",
                    heightOffset: 0.55,
                    ruggednessMultiplier: 1.45,
                    propDensityMultiplier: 0.95,
                    materialIdentifier: "biome.mountain",
                    placeholderColor: BiomeColor(red: 0.45, green: 0.45, blue: 0.40),
                    terrainMaterial: .definition(for: .rock),
                    preferredTemperature: -1.0...0.35,
                    preferredHumidity: -0.55...0.55,
                    preferredAltitude: 0.45...1.0
                )
            )
        case .marsh:
            Biome(
                type: .marsh,
                parameters: BiomeParameters(
                    displayName: "Marsh",
                    heightOffset: -0.25,
                    ruggednessMultiplier: 0.45,
                    propDensityMultiplier: 1.10,
                    materialIdentifier: "biome.marsh",
                    placeholderColor: BiomeColor(red: 0.18, green: 0.48, blue: 0.34),
                    terrainMaterial: .definition(for: .wetValley),
                    preferredTemperature: -0.10...0.75,
                    preferredHumidity: 0.35...1.0,
                    preferredAltitude: -0.60...0.20
                )
            )
        case .taiga:
            Biome(
                type: .taiga,
                parameters: BiomeParameters(
                    displayName: "Taiga",
                    heightOffset: 0.12,
                    ruggednessMultiplier: 0.92,
                    propDensityMultiplier: 1.05,
                    materialIdentifier: "biome.taiga",
                    placeholderColor: BiomeColor(red: 0.13, green: 0.32, blue: 0.28),
                    terrainMaterial: .definition(for: .dirt),
                    preferredTemperature: -1.0 ... -0.25,
                    preferredHumidity: -0.05...0.65,
                    preferredAltitude: -0.20...0.55
                )
            )
        case .coast:
            Biome(
                type: .coast,
                parameters: BiomeParameters(
                    displayName: "Coast",
                    heightOffset: -0.18,
                    ruggednessMultiplier: 0.50,
                    propDensityMultiplier: 0.55,
                    materialIdentifier: "biome.coast",
                    placeholderColor: BiomeColor(red: 0.58, green: 0.62, blue: 0.42),
                    terrainMaterial: .definition(for: .sand),
                    preferredTemperature: -0.35...0.85,
                    preferredHumidity: -0.10...0.80,
                    preferredAltitude: -0.25...0.25
                )
            )
        case .freshwater:
            Biome(
                type: .freshwater,
                parameters: BiomeParameters(
                    displayName: "Freshwater",
                    heightOffset: -0.35,
                    ruggednessMultiplier: 0.30,
                    propDensityMultiplier: 0.35,
                    materialIdentifier: "biome.freshwater",
                    placeholderColor: BiomeColor(red: 0.10, green: 0.30, blue: 0.48),
                    terrainMaterial: .definition(for: .wetValley),
                    preferredTemperature: -0.60...0.75,
                    preferredHumidity: 0.20...1.0,
                    preferredAltitude: -0.80...0.25
                )
            )
        }
    }
}

public typealias BiomeDefinition = Biome
