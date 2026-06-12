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

public struct WorldRenderDNA: Hashable, Codable, Sendable {
    public var paletteSeed: UInt64
    public var exposureBias: Float
    public var lightTemperature: Float

    public init(paletteSeed: UInt64, exposureBias: Float, lightTemperature: Float) {
        self.paletteSeed = paletteSeed
        self.exposureBias = exposureBias
        self.lightTemperature = lightTemperature
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldRenderDNA {
        var random = versionedRNG(worldSeed: worldSeed, domain: .render, generatorVersions: generatorVersions)

        return WorldRenderDNA(
            paletteSeed: random.next(),
            exposureBias: random.nextFloat(in: -0.10...0.12),
            lightTemperature: random.nextFloat(in: 4_800...6_800)
        )
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
