public struct RenderToneMappingState: Equatable, Hashable, Codable, Sendable {
    public let exposure: Float
    public let contrast: Float
    public let saturation: Float

    public init(exposure: Float, contrast: Float, saturation: Float) {
        self.exposure = Self.clamped(exposure, lower: 0.25, upper: 2.5)
        self.contrast = Self.clamped(contrast, lower: 0.65, upper: 1.45)
        self.saturation = Self.clamped(saturation, lower: 0.55, upper: 1.45)
    }

    public static let `default` = RenderToneMappingState(exposure: 1, contrast: 1, saturation: 1)

    private static func clamped(_ value: Float, lower: Float, upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}

public struct RenderSkyLightingState: Equatable, Hashable, Codable, Sendable {
    public let tint: BiomeColor
    public let indirectIntensity: Float
    public let fogDensity: Float

    public init(tint: BiomeColor, indirectIntensity: Float, fogDensity: Float) {
        self.tint = tint
        self.indirectIntensity = Self.clamped(indirectIntensity, lower: 0, upper: 1.5)
        self.fogDensity = Self.clamped(fogDensity, lower: 0, upper: 0.35)
    }

    public static let `default` = RenderSkyLightingState(
        tint: BiomeColor(red: 0.78, green: 0.86, blue: 0.95),
        indirectIntensity: 0.35,
        fogDensity: 0.025
    )

    private static func clamped(_ value: Float, lower: Float, upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}

public struct RenderEnvironmentState: Equatable, Hashable, Codable, Sendable {
    public let renderDNA: WorldRenderDNA
    public let toneMapping: RenderToneMappingState
    public let sky: RenderSkyLightingState
    public let surfaceState: SurfaceState

    public init(
        renderDNA: WorldRenderDNA,
        toneMapping: RenderToneMappingState,
        sky: RenderSkyLightingState,
        surfaceState: SurfaceState
    ) {
        self.renderDNA = renderDNA
        self.toneMapping = toneMapping
        self.sky = sky
        self.surfaceState = surfaceState
    }

    public static let `default` = RenderEnvironmentState(
        renderDNA: WorldRenderDNA.make(worldSeed: WorldSeed(1)),
        toneMapping: .default,
        sky: .default,
        surfaceState: .dry
    )

    public static func make(
        worldDNA: WorldDNA,
        primaryBiome: Biome?,
        terrainSample: TerrainSample?,
        simulationTime: Float
    ) -> RenderEnvironmentState {
        let renderDNA = worldDNA.render
        let biome = primaryBiome ?? terrainSample?.materialWeights.primaryBiome ?? Biome.definition(for: .grassland)
        let surfaceState = SurfaceState.make(
            terrainSample: terrainSample,
            renderDNA: renderDNA,
            simulationTime: simulationTime
        )

        return RenderEnvironmentState(
            renderDNA: renderDNA,
            toneMapping: RenderToneMappingState(
                exposure: 1 + renderDNA.exposureBias,
                contrast: contrast(for: renderDNA.contrastCurve),
                saturation: saturation(for: renderDNA.colorStyle)
            ),
            sky: RenderSkyLightingState(
                tint: skyTint(renderDNA: renderDNA, biome: biome),
                indirectIntensity: indirectIntensity(for: renderDNA),
                fogDensity: fogDensity(renderDNA: renderDNA, sample: terrainSample)
            ),
            surfaceState: surfaceState
        )
    }

    private static func contrast(for curve: RenderContrastCurve) -> Float {
        switch curve {
        case .soft:
            0.88
        case .filmic:
            1.0
        case .crisp:
            1.14
        }
    }

    private static func saturation(for style: RenderColorStyle) -> Float {
        switch style {
        case .natural:
            1.0
        case .coolMist:
            0.92
        case .warmEarth:
            1.08
        case .highlandClear:
            1.12
        }
    }

    private static func skyTint(renderDNA: WorldRenderDNA, biome: Biome) -> BiomeColor {
        let warmAmount = clamped((renderDNA.lightTemperature - 4_800) / 2_000, lower: 0, upper: 1)
        let coolSky = BiomeColor(red: 0.64, green: 0.76, blue: 0.96)
        let warmSky = BiomeColor(red: 0.92, green: 0.84, blue: 0.70)
        let base = mix(coolSky, warmSky, amount: warmAmount)
        let biomeTint = biome.previewColor
        let tintStrength = 0.05 + renderDNA.biomeMaterialMutation * 0.12

        return mix(base, biomeTint, amount: tintStrength)
    }

    private static func indirectIntensity(for renderDNA: WorldRenderDNA) -> Float {
        switch renderDNA.pbrProfile {
        case .stylizedPlausible:
            0.42
        case .balanced:
            0.35
        case .highFidelity:
            0.30
        }
    }

    private static func fogDensity(renderDNA: WorldRenderDNA, sample: TerrainSample?) -> Float {
        let moistureFog = sample.map { max($0.moisture - 0.55, 0) * 0.06 } ?? 0
        let coldFog = sample.map { max(0.20 - $0.temperature, 0) * 0.08 } ?? 0

        return clamped(0.025 + renderDNA.fogDensityBias + moistureFog + coldFog, lower: 0, upper: 0.35)
    }

    private static func clamped(_ value: Float, lower: Float, upper: Float) -> Float {
        min(max(value, lower), upper)
    }

    private static func mix(_ lhs: BiomeColor, _ rhs: BiomeColor, amount: Float) -> BiomeColor {
        let amount = clamped(amount, lower: 0, upper: 1)

        return BiomeColor(
            red: lhs.red + (rhs.red - lhs.red) * amount,
            green: lhs.green + (rhs.green - lhs.green) * amount,
            blue: lhs.blue + (rhs.blue - lhs.blue) * amount
        )
    }
}

public extension SurfaceState {
    static func make(
        terrainSample: TerrainSample?,
        renderDNA: WorldRenderDNA,
        simulationTime: Float
    ) -> SurfaceState {
        guard let terrainSample else {
            return .dry
        }

        let intensity = renderDNA.weatherSurfaceIntensity
        let wetness = wetnessAmount(sample: terrainSample, renderDNA: renderDNA) * intensity
        let snow = snowAmount(sample: terrainSample, renderDNA: renderDNA) * intensity
        let dust = dustAmount(sample: terrainSample, renderDNA: renderDNA) * intensity
        let mud = min(max(terrainSample.waterDepth * 2.4 + max(terrainSample.moisture - 0.70, 0) * 1.2, 0), 1)
        let agePulse = 0.85 + 0.15 * max(0, min(1, renderDNA.worldAgeVisualBias))
        let moss = mossAmount(sample: terrainSample) * intensity * agePulse

        return SurfaceState(
            wetness: wetness,
            snow: snow,
            dust: dust,
            mud: mud,
            moss: moss
        )
    }

    private static func wetnessAmount(sample: TerrainSample, renderDNA: WorldRenderDNA) -> Float {
        let base = max(sample.waterDepth * 2.0, max(sample.moisture - 0.62, 0) * 1.9)

        switch renderDNA.wetnessModel {
        case .subtleFilm:
            return min(max(base * 0.78, 0), 1)
        case .puddled:
            return min(max(base * 1.12, 0), 1)
        }
    }

    private static func snowAmount(sample: TerrainSample, renderDNA: WorldRenderDNA) -> Float {
        let cold = max(0.24 - sample.temperature, 0) * 3.8
        let slopeRetention = max(1 - sample.slope * 2.2, 0)
        let sheltered = renderDNA.snowModel == .windSheltered ? max(1 - sample.roughness * 0.35, 0) : 1

        return min(max(cold * slopeRetention * sheltered, 0), 1)
    }

    private static func dustAmount(sample: TerrainSample, renderDNA: WorldRenderDNA) -> Float {
        let dryHeat = max(sample.temperature - 0.58, 0) * max(0.46 - sample.moisture, 0) * 3.8
        let exposure = renderDNA.dustModel == .biomeDriven ? 0.85 + sample.slope * 0.35 : 1

        return min(max(dryHeat * exposure, 0), 1)
    }

    private static func mossAmount(sample: TerrainSample) -> Float {
        let humid = max(sample.moisture - 0.58, 0) * 1.7
        let temperate = max(1 - abs(sample.temperature - 0.46) * 2.4, 0)
        let shadedSlope = max(1 - sample.slope * 1.4, 0)

        return min(max(humid * temperate * shadedSlope, 0), 1)
    }
}
