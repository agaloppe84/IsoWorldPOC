public struct WorldDNA: Hashable, Codable, Sendable {
    public var terrain: WorldTerrainDNA
    public var biomes: WorldBiomeDNA
    public var render: WorldRenderDNA
    public var rpg: WorldRPGDNA
    public var style: WorldStyleGenome

    public init(
        terrain: WorldTerrainDNA,
        biomes: WorldBiomeDNA,
        render: WorldRenderDNA,
        rpg: WorldRPGDNA,
        style: WorldStyleGenome
    ) {
        self.terrain = terrain
        self.biomes = biomes
        self.render = render
        self.rpg = rpg
        self.style = style
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldDNA {
        WorldDNA(
            terrain: WorldTerrainDNA.make(worldSeed: worldSeed, generatorVersions: generatorVersions),
            biomes: WorldBiomeDNA.make(worldSeed: worldSeed, generatorVersions: generatorVersions),
            render: WorldRenderDNA.make(worldSeed: worldSeed, generatorVersions: generatorVersions),
            rpg: WorldRPGDNA.make(worldSeed: worldSeed, generatorVersions: generatorVersions),
            style: WorldStyleGenome.make(worldSeed: worldSeed, generatorVersions: generatorVersions)
        )
    }
}

public struct WorldTerrainDNA: Hashable, Codable, Sendable {
    public var continentScale: Float
    public var verticalScale: Float
    public var erosionSeed: UInt64

    public init(continentScale: Float, verticalScale: Float, erosionSeed: UInt64) {
        self.continentScale = continentScale
        self.verticalScale = verticalScale
        self.erosionSeed = erosionSeed
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldTerrainDNA {
        var random = versionedRNG(worldSeed: worldSeed, domain: .terrain, generatorVersions: generatorVersions)

        return WorldTerrainDNA(
            continentScale: random.nextFloat(in: 0.80...1.25),
            verticalScale: random.nextFloat(in: 0.75...1.35),
            erosionSeed: random.next()
        )
    }
}

public struct WorldBiomeDNA: Hashable, Codable, Sendable {
    public var climateSeed: UInt64
    public var transitionSharpness: Float
    public var moistureBias: Float
    public var temperatureBias: Float

    public init(
        climateSeed: UInt64,
        transitionSharpness: Float,
        moistureBias: Float,
        temperatureBias: Float
    ) {
        self.climateSeed = climateSeed
        self.transitionSharpness = transitionSharpness
        self.moistureBias = moistureBias
        self.temperatureBias = temperatureBias
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldBiomeDNA {
        var random = versionedRNG(worldSeed: worldSeed, domain: .biomes, generatorVersions: generatorVersions)

        return WorldBiomeDNA(
            climateSeed: random.next(),
            transitionSharpness: random.nextFloat(in: 0.55...1.25),
            moistureBias: random.nextFloat(in: -0.18...0.18),
            temperatureBias: random.nextFloat(in: -0.16...0.16)
        )
    }
}

public enum RenderPBRProfile: String, CaseIterable, Codable, Sendable {
    case stylizedPlausible
    case balanced
    case highFidelity
}

public enum RenderColorStyle: String, CaseIterable, Codable, Sendable {
    case natural
    case coolMist
    case warmEarth
    case highlandClear
}

public enum RenderContrastCurve: String, CaseIterable, Codable, Sendable {
    case soft
    case filmic
    case crisp
}

public enum RenderMaterialComplexity: String, CaseIterable, Codable, Sendable {
    case compact
    case balanced
    case rich
}

public enum RenderWetnessModel: String, CaseIterable, Codable, Sendable {
    case subtleFilm
    case puddled
}

public enum RenderSnowModel: String, CaseIterable, Codable, Sendable {
    case altitudeAndCold
    case windSheltered
}

public enum RenderDustModel: String, CaseIterable, Codable, Sendable {
    case dryExposure
    case biomeDriven
}

public struct WorldRenderDNA: Hashable, Codable, Sendable {
    public var paletteSeed: UInt64
    public var exposureBias: Float
    public var lightTemperature: Float
    public var pbrProfile: RenderPBRProfile
    public var colorStyle: RenderColorStyle
    public var contrastCurve: RenderContrastCurve
    public var materialComplexity: RenderMaterialComplexity
    public var textureDensityScale: Float
    public var weatherSurfaceIntensity: Float
    public var biomeMaterialMutation: Float
    public var fogDensityBias: Float
    public var shadowSoftnessBias: Float
    public var wetnessModel: RenderWetnessModel
    public var snowModel: RenderSnowModel
    public var dustModel: RenderDustModel
    public var worldAgeVisualBias: Float

    public init(
        paletteSeed: UInt64,
        exposureBias: Float,
        lightTemperature: Float,
        pbrProfile: RenderPBRProfile = .balanced,
        colorStyle: RenderColorStyle = .natural,
        contrastCurve: RenderContrastCurve = .filmic,
        materialComplexity: RenderMaterialComplexity = .balanced,
        textureDensityScale: Float = 1,
        weatherSurfaceIntensity: Float = 1,
        biomeMaterialMutation: Float = 0,
        fogDensityBias: Float = 0,
        shadowSoftnessBias: Float = 0,
        wetnessModel: RenderWetnessModel = .subtleFilm,
        snowModel: RenderSnowModel = .altitudeAndCold,
        dustModel: RenderDustModel = .dryExposure,
        worldAgeVisualBias: Float = 0.5
    ) {
        self.paletteSeed = paletteSeed
        self.exposureBias = Self.clamped(exposureBias, lower: -0.45, upper: 0.45)
        self.lightTemperature = Self.clamped(lightTemperature, lower: 3_200, upper: 8_500)
        self.pbrProfile = pbrProfile
        self.colorStyle = colorStyle
        self.contrastCurve = contrastCurve
        self.materialComplexity = materialComplexity
        self.textureDensityScale = Self.clamped(textureDensityScale, lower: 0.5, upper: 2)
        self.weatherSurfaceIntensity = Self.clamped(weatherSurfaceIntensity, lower: 0, upper: 1.5)
        self.biomeMaterialMutation = Self.clamped(biomeMaterialMutation, lower: 0, upper: 1)
        self.fogDensityBias = Self.clamped(fogDensityBias, lower: -0.08, upper: 0.16)
        self.shadowSoftnessBias = Self.clamped(shadowSoftnessBias, lower: -1, upper: 1)
        self.wetnessModel = wetnessModel
        self.snowModel = snowModel
        self.dustModel = dustModel
        self.worldAgeVisualBias = Self.clamped(worldAgeVisualBias, lower: 0, upper: 1)
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldRenderDNA {
        var random = versionedRNG(worldSeed: worldSeed, domain: .render, generatorVersions: generatorVersions)

        return WorldRenderDNA(
            paletteSeed: random.next(),
            exposureBias: random.nextFloat(in: -0.10...0.12),
            lightTemperature: random.nextFloat(in: 4_800...6_800),
            pbrProfile: random.element(from: RenderPBRProfile.allCases),
            colorStyle: random.element(from: RenderColorStyle.allCases),
            contrastCurve: random.element(from: RenderContrastCurve.allCases),
            materialComplexity: random.element(from: RenderMaterialComplexity.allCases),
            textureDensityScale: random.nextFloat(in: 0.82...1.28),
            weatherSurfaceIntensity: random.nextFloat(in: 0.72...1.20),
            biomeMaterialMutation: random.nextFloat(in: 0.10...0.48),
            fogDensityBias: random.nextFloat(in: -0.02...0.05),
            shadowSoftnessBias: random.nextFloat(in: -0.20...0.35),
            wetnessModel: random.element(from: RenderWetnessModel.allCases),
            snowModel: random.element(from: RenderSnowModel.allCases),
            dustModel: random.element(from: RenderDustModel.allCases),
            worldAgeVisualBias: random.nextFloat(in: 0.18...0.86)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case paletteSeed
        case exposureBias
        case lightTemperature
        case pbrProfile
        case colorStyle
        case contrastCurve
        case materialComplexity
        case textureDensityScale
        case weatherSurfaceIntensity
        case biomeMaterialMutation
        case fogDensityBias
        case shadowSoftnessBias
        case wetnessModel
        case snowModel
        case dustModel
        case worldAgeVisualBias
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            paletteSeed: try container.decode(UInt64.self, forKey: .paletteSeed),
            exposureBias: try container.decode(Float.self, forKey: .exposureBias),
            lightTemperature: try container.decode(Float.self, forKey: .lightTemperature),
            pbrProfile: try container.decodeIfPresent(RenderPBRProfile.self, forKey: .pbrProfile) ?? .balanced,
            colorStyle: try container.decodeIfPresent(RenderColorStyle.self, forKey: .colorStyle) ?? .natural,
            contrastCurve: try container.decodeIfPresent(RenderContrastCurve.self, forKey: .contrastCurve) ?? .filmic,
            materialComplexity: try container.decodeIfPresent(RenderMaterialComplexity.self, forKey: .materialComplexity) ?? .balanced,
            textureDensityScale: try container.decodeIfPresent(Float.self, forKey: .textureDensityScale) ?? 1,
            weatherSurfaceIntensity: try container.decodeIfPresent(Float.self, forKey: .weatherSurfaceIntensity) ?? 1,
            biomeMaterialMutation: try container.decodeIfPresent(Float.self, forKey: .biomeMaterialMutation) ?? 0,
            fogDensityBias: try container.decodeIfPresent(Float.self, forKey: .fogDensityBias) ?? 0,
            shadowSoftnessBias: try container.decodeIfPresent(Float.self, forKey: .shadowSoftnessBias) ?? 0,
            wetnessModel: try container.decodeIfPresent(RenderWetnessModel.self, forKey: .wetnessModel) ?? .subtleFilm,
            snowModel: try container.decodeIfPresent(RenderSnowModel.self, forKey: .snowModel) ?? .altitudeAndCold,
            dustModel: try container.decodeIfPresent(RenderDustModel.self, forKey: .dustModel) ?? .dryExposure,
            worldAgeVisualBias: try container.decodeIfPresent(Float.self, forKey: .worldAgeVisualBias) ?? 0.5
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(paletteSeed, forKey: .paletteSeed)
        try container.encode(exposureBias, forKey: .exposureBias)
        try container.encode(lightTemperature, forKey: .lightTemperature)
        try container.encode(pbrProfile, forKey: .pbrProfile)
        try container.encode(colorStyle, forKey: .colorStyle)
        try container.encode(contrastCurve, forKey: .contrastCurve)
        try container.encode(materialComplexity, forKey: .materialComplexity)
        try container.encode(textureDensityScale, forKey: .textureDensityScale)
        try container.encode(weatherSurfaceIntensity, forKey: .weatherSurfaceIntensity)
        try container.encode(biomeMaterialMutation, forKey: .biomeMaterialMutation)
        try container.encode(fogDensityBias, forKey: .fogDensityBias)
        try container.encode(shadowSoftnessBias, forKey: .shadowSoftnessBias)
        try container.encode(wetnessModel, forKey: .wetnessModel)
        try container.encode(snowModel, forKey: .snowModel)
        try container.encode(dustModel, forKey: .dustModel)
        try container.encode(worldAgeVisualBias, forKey: .worldAgeVisualBias)
    }

    private static func clamped(_ value: Float, lower: Float, upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}

public struct WorldStyleGenome: Hashable, Codable, Sendable {
    public var artDirectionSeed: UInt64
    public var saturation: Float
    public var geometryRoundness: Float

    public init(artDirectionSeed: UInt64, saturation: Float, geometryRoundness: Float) {
        self.artDirectionSeed = artDirectionSeed
        self.saturation = saturation
        self.geometryRoundness = geometryRoundness
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldStyleGenome {
        var random = versionedRNG(worldSeed: worldSeed, domain: .style, generatorVersions: generatorVersions)

        return WorldStyleGenome(
            artDirectionSeed: random.next(),
            saturation: random.nextFloat(in: 0.78...1.18),
            geometryRoundness: random.nextFloat(in: 0.10...0.42)
        )
    }
}

private func versionedRNG(
    worldSeed: WorldSeed,
    domain: SeedDomain,
    generatorVersions: GeneratorVersionTable
) -> StableRNG {
    let versionHash = StableHash.make { builder in
        builder.combine(generatorVersions.version(for: domain))
    }

    return StableRNG(seed: worldSeed, domain: domain, values: [versionHash.value])
}

private extension StableRNG {
    mutating func element<Element>(from values: [Element]) -> Element {
        values[nextInt(upperBound: values.count)]
    }
}
