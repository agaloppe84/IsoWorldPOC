public struct GenerationContext: Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let worldDNA: WorldDNA
    public let generatorVersions: GeneratorVersionTable
    public let domain: SeedDomain

    public init(
        worldSeed: WorldSeed,
        worldDNA: WorldDNA,
        generatorVersions: GeneratorVersionTable = .current,
        domain: SeedDomain
    ) {
        self.worldSeed = worldSeed
        self.worldDNA = worldDNA
        self.generatorVersions = generatorVersions
        self.domain = domain
    }

    public init(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current,
        domain: SeedDomain = .worldDNA
    ) {
        self.init(
            worldSeed: worldSeed,
            worldDNA: WorldDNA.make(worldSeed: worldSeed, generatorVersions: generatorVersions),
            generatorVersions: generatorVersions,
            domain: domain
        )
    }

    public func rng(
        coordinate: ChunkCoordinate? = nil,
        values: [UInt64] = []
    ) -> StableRNG {
        StableRNG(
            seed: worldSeed,
            domain: domain,
            coordinate: coordinate,
            values: versionedValues(appending: values)
        )
    }

    public func stableID(
        coordinate: ChunkCoordinate? = nil,
        values: [UInt64] = []
    ) -> StableID {
        StableID.make(
            worldSeed: worldSeed,
            domain: domain,
            coordinate: coordinate,
            values: versionedValues(appending: values)
        )
    }

    private func versionedValues(appending values: [UInt64]) -> [UInt64] {
        let versionHash = StableHash.make { builder in
            builder.combine(generatorVersions.version(for: domain))
        }

        return [versionHash.value] + values
    }
}
