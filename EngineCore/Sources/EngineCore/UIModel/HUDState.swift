public enum UIWeatherKind: String, CaseIterable, Codable, Sendable {
    case clear
    case wet
    case storm
    case cold
    case dry
}

public struct PlayerHUDState: Equatable, Hashable, Codable, Sendable {
    public let health: Float
    public let stamina: Float
    public let fatigue: Float
    public let wetness: Float
    public let movementStance: CharacterMovementStance

    public init(
        health: Float,
        stamina: Float,
        fatigue: Float,
        wetness: Float,
        movementStance: CharacterMovementStance
    ) {
        self.health = Self.clamped01(health)
        self.stamina = Self.clamped01(stamina)
        self.fatigue = Self.clamped01(fatigue)
        self.wetness = Self.clamped01(wetness)
        self.movementStance = movementStance
    }

    public init(runtimeState: CharacterRuntimeState) {
        self.init(
            health: runtimeState.health,
            stamina: runtimeState.stamina,
            fatigue: runtimeState.fatigue,
            wetness: runtimeState.wetness,
            movementStance: runtimeState.movementStance
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

public struct WeatherHUDState: Equatable, Hashable, Codable, Sendable {
    public let kind: UIWeatherKind
    public let severity: Float
    public let label: String

    public init(kind: UIWeatherKind, severity: Float, label: String) {
        self.kind = kind
        self.severity = min(max(severity.isFinite ? severity : 0, 0), 1)
        self.label = label
    }
}

public struct BiomeHUDState: Equatable, Hashable, Codable, Sendable {
    public let biomeType: BiomeType
    public let displayName: String
    public let tint: UIStyleColor

    public init(biome: Biome) {
        self.biomeType = biome.type
        self.displayName = biome.displayName
        self.tint = UIStyleColor(biome.previewColor)
    }
}

public struct HUDState: Equatable, Hashable, Codable, Sendable {
    public static let empty = HUDState(
        player: PlayerHUDState(
            health: 1,
            stamina: 1,
            fatigue: 0,
            wetness: 0,
            movementStance: .standing
        ),
        weather: WeatherHUDState(kind: .clear, severity: 0, label: "Clear"),
        biome: BiomeHUDState(biome: Biome.definition(for: .grassland)),
        terrainPrompt: nil,
        isVisible: false
    )

    public let player: PlayerHUDState
    public let weather: WeatherHUDState
    public let biome: BiomeHUDState
    public let terrainPrompt: String?
    public let isVisible: Bool

    public init(
        player: PlayerHUDState,
        weather: WeatherHUDState,
        biome: BiomeHUDState,
        terrainPrompt: String?,
        isVisible: Bool = true
    ) {
        self.player = player
        self.weather = weather
        self.biome = biome
        self.terrainPrompt = terrainPrompt
        self.isVisible = isVisible
    }
}
