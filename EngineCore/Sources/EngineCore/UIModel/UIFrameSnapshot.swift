public struct UIFrameSnapshot: Equatable, Hashable, Codable, Sendable {
    public static let empty = UIFrameSnapshot(
        worldSeed: WorldSeed(0),
        simulationTime: 0,
        dna: UIWorldDNA(
            seed: 0,
            themeID: .neutral,
            informationDensity: .standard,
            diegeticLevel: .nonDiegetic,
            materialLanguage: .neutralGlass,
            shapeLanguage: .softRect,
            biomeReactivity: 0,
            motionIntensity: 0,
            legibilityBias: 1
        ),
        theme: .definition(for: .neutral),
        hud: .empty
    )

    public let worldSeed: WorldSeed
    public let simulationTime: Float
    public let dna: UIWorldDNA
    public let theme: UITheme
    public let hud: HUDState

    public var hasVisibleHUD: Bool {
        hud.isVisible
    }

    public init(
        worldSeed: WorldSeed,
        simulationTime: Float,
        dna: UIWorldDNA,
        theme: UITheme,
        hud: HUDState
    ) {
        self.worldSeed = worldSeed
        self.simulationTime = max(simulationTime.isFinite ? simulationTime : 0, 0)
        self.dna = dna
        self.theme = theme
        self.hud = hud
    }

    public static func make(
        worldSeed: WorldSeed,
        simulationTime: Float,
        dna: UIWorldDNA,
        player: PlayerHUDState,
        biome: Biome,
        weather: WeatherHUDState,
        terrainPrompt: String? = nil,
        isVisible: Bool = true
    ) -> UIFrameSnapshot {
        UIFrameSnapshot(
            worldSeed: worldSeed,
            simulationTime: simulationTime,
            dna: dna,
            theme: UITheme.resolved(dna: dna, biome: biome),
            hud: HUDState(
                player: player,
                weather: weather,
                biome: BiomeHUDState(biome: biome),
                terrainPrompt: terrainPrompt,
                isVisible: isVisible
            )
        )
    }
}
