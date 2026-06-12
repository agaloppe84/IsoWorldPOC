public enum UIThemeID: String, CaseIterable, Codable, Sendable {
    case neutral
    case parchment
    case sciFi = "sci-fi"
}

public enum UIInformationDensity: String, CaseIterable, Codable, Sendable {
    case compact
    case standard
    case dense
}

public enum UIDiegeticLevel: String, CaseIterable, Codable, Sendable {
    case nonDiegetic
    case semiDiegetic
    case diegetic
}

public enum UIMaterialLanguage: String, CaseIterable, Codable, Sendable {
    case neutralGlass
    case parchmentInk
    case holoGlass
}

public enum UIShapeLanguage: String, CaseIterable, Codable, Sendable {
    case softRect
    case framedParchment
    case angularTech
}

public struct UIWorldDNA: Equatable, Hashable, Codable, Sendable {
    public let seed: UInt64
    public let themeID: UIThemeID
    public let informationDensity: UIInformationDensity
    public let diegeticLevel: UIDiegeticLevel
    public let materialLanguage: UIMaterialLanguage
    public let shapeLanguage: UIShapeLanguage
    public let biomeReactivity: Float
    public let motionIntensity: Float
    public let legibilityBias: Float

    public init(
        seed: UInt64,
        themeID: UIThemeID,
        informationDensity: UIInformationDensity,
        diegeticLevel: UIDiegeticLevel,
        materialLanguage: UIMaterialLanguage,
        shapeLanguage: UIShapeLanguage,
        biomeReactivity: Float,
        motionIntensity: Float,
        legibilityBias: Float
    ) {
        self.seed = seed
        self.themeID = themeID
        self.informationDensity = informationDensity
        self.diegeticLevel = diegeticLevel
        self.materialLanguage = materialLanguage
        self.shapeLanguage = shapeLanguage
        self.biomeReactivity = Self.clamped01(biomeReactivity)
        self.motionIntensity = Self.clamped01(motionIntensity)
        self.legibilityBias = Self.clamped01(legibilityBias)
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> UIWorldDNA {
        let seedValue = StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.ui)
            builder.combine(generatorVersions.version(for: .ui))
        }.value
        var rng = StableRNG(seedValue: seedValue)
        let theme = UIThemeID.allCases[rng.nextInt(upperBound: UIThemeID.allCases.count)]
        let densityRoll = rng.nextUnitFloat()
        let density: UIInformationDensity = densityRoll < 0.20 ? .compact : (densityRoll > 0.86 ? .dense : .standard)

        return UIWorldDNA(
            seed: seedValue,
            themeID: theme,
            informationDensity: density,
            diegeticLevel: rng.nextUnitFloat() > 0.78 ? .semiDiegetic : .nonDiegetic,
            materialLanguage: materialLanguage(for: theme),
            shapeLanguage: shapeLanguage(for: theme),
            biomeReactivity: 0.35 + rng.nextUnitFloat() * 0.35,
            motionIntensity: 0.10 + rng.nextUnitFloat() * 0.35,
            legibilityBias: 0.76 + rng.nextUnitFloat() * 0.18
        )
    }

    private static func materialLanguage(for theme: UIThemeID) -> UIMaterialLanguage {
        switch theme {
        case .neutral:
            .neutralGlass
        case .parchment:
            .parchmentInk
        case .sciFi:
            .holoGlass
        }
    }

    private static func shapeLanguage(for theme: UIThemeID) -> UIShapeLanguage {
        switch theme {
        case .neutral:
            .softRect
        case .parchment:
            .framedParchment
        case .sciFi:
            .angularTech
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}
