public struct PropPlacementGenerator: Sendable {
    public static let defaultMaxPropsPerChunk = 24

    public let seed: WorldSeed
    public let maxPropsPerChunk: Int

    public init(seed: WorldSeed, maxPropsPerChunk: Int = Self.defaultMaxPropsPerChunk) {
        precondition(maxPropsPerChunk >= 0, "maxPropsPerChunk must be zero or positive.")

        self.seed = seed
        self.maxPropsPerChunk = maxPropsPerChunk
    }

    public func placements(
        for coordinate: ChunkCoordinate,
        samplesPerChunk: Int = ChunkHeightmap.resolution
    ) -> [PropPlacement] {
        let biome = BiomeSampler(seed: seed).dominantBiome(
            for: coordinate,
            samplesPerChunk: samplesPerChunk
        )

        return placements(
            for: coordinate,
            biome: biome,
            samplesPerChunk: samplesPerChunk
        )
    }

    public func placements(
        for coordinate: ChunkCoordinate,
        biome: Biome,
        samplesPerChunk: Int = ChunkHeightmap.resolution
    ) -> [PropPlacement] {
        precondition(samplesPerChunk > 1, "samplesPerChunk must contain at least two samples.")

        if samplesPerChunk == ChunkHeightmap.resolution {
            return placements(
                for: coordinate,
                biome: biome,
                terrainSampleGrid: TerrainSystem(seed: seed).sampleGrid(for: coordinate)
            )
        }

        guard maxPropsPerChunk > 0 else {
            return []
        }

        var random = StableRNG(seedValue: chunkSeed(for: coordinate, biomeType: biome.type))
        let count = targetPropCount(for: biome, random: &random)
        let clampedCount = min(count, maxPropsPerChunk)
        let maxLocalPosition = Float(samplesPerChunk - 1)
        let margin = min(Float(2), maxLocalPosition * 0.25)
        let usableSpan = max(Float(0), maxLocalPosition - margin * 2)

        return (0..<clampedCount).map { index in
            let type = propType(for: biome.type, roll: randomUnit(&random))
            let localX = margin + randomUnit(&random) * usableSpan
            let localZ = margin + randomUnit(&random) * usableSpan
            let worldX = Float(coordinate.x * samplesPerChunk) + localX
            let worldZ = Float(coordinate.z * samplesPerChunk) + localZ

            return PropPlacement(
                placementIndex: index,
                type: type,
                localX: localX,
                localZ: localZ,
                worldX: worldX,
                worldZ: worldZ,
                rotationRadians: randomUnit(&random) * Float.pi * 2,
                scale: scale(for: type, random: &random)
            )
        }
    }

    public func placements(
        for coordinate: ChunkCoordinate,
        biome: Biome,
        terrainSampleGrid: TerrainSampleGrid
    ) -> [PropPlacement] {
        PropSystem(seed: seed, maxPropsPerChunk: maxPropsPerChunk).placements(
            for: coordinate,
            biome: biome,
            terrainSampleGrid: terrainSampleGrid
        )
    }

    private func targetPropCount(for biome: Biome, random: inout StableRNG) -> Int {
        let baseCount: Int
        let jitterRange: Int

        switch biome.type {
        case .grassland:
            baseCount = 4
            jitterRange = 2
        case .temperateForest:
            baseCount = 15
            jitterRange = 4
        case .mountain:
            baseCount = 10
            jitterRange = 3
        case .desert:
            baseCount = 4
            jitterRange = 2
        case .marsh:
            baseCount = 9
            jitterRange = 3
        case .taiga:
            baseCount = 11
            jitterRange = 3
        case .coast:
            baseCount = 5
            jitterRange = 2
        case .freshwater:
            baseCount = 3
            jitterRange = 1
        }

        let jitter = Int(random.next() % UInt64(jitterRange + 1))
        let densityAdjusted = Float(baseCount + jitter) * biome.propDensityMultiplier

        return max(0, Int(densityAdjusted.rounded()))
    }

    private func propType(for biomeType: BiomeType, roll: Float) -> PropType {
        switch biomeType {
        case .grassland:
            if roll < 0.34 { return .grass }
            if roll < 0.58 { return .pebble }
            if roll < 0.78 { return .rock }
            if roll < 0.94 { return .tree }
            return .crystal
        case .temperateForest:
            if roll < 0.42 { return .tree }
            if roll < 0.70 { return .grass }
            if roll < 0.84 { return .deadwood }
            if roll < 0.96 { return .rock }
            return .crystal
        case .mountain:
            if roll < 0.52 { return .rock }
            if roll < 0.74 { return .pebble }
            if roll < 0.94 { return .crystal }
            return .tree
        case .desert:
            if roll < 0.48 { return .pebble }
            if roll < 0.78 { return .rock }
            if roll < 0.92 { return .crystal }
            if roll < 0.98 { return .deadwood }
            return .grass
        case .marsh:
            if roll < 0.36 { return .grass }
            if roll < 0.58 { return .tree }
            if roll < 0.76 { return .deadwood }
            if roll < 0.92 { return .rock }
            return .crystal
        case .taiga:
            if roll < 0.44 { return .tree }
            if roll < 0.64 { return .grass }
            if roll < 0.80 { return .deadwood }
            if roll < 0.94 { return .rock }
            return .crystal
        case .coast:
            if roll < 0.40 { return .pebble }
            if roll < 0.66 { return .rock }
            if roll < 0.78 { return .deadwood }
            if roll < 0.90 { return .grass }
            return .crystal
        case .freshwater:
            if roll < 0.32 { return .grass }
            if roll < 0.54 { return .pebble }
            if roll < 0.76 { return .tree }
            if roll < 0.92 { return .deadwood }
            return .crystal
        }
    }

    private func scale(for type: PropType, random: inout StableRNG) -> Float {
        let roll = randomUnit(&random)

        switch type {
        case .rock:
            return 0.65 + roll * 0.65
        case .pebble:
            return 0.30 + roll * 0.32
        case .grass:
            return 0.45 + roll * 0.40
        case .tree:
            return 0.85 + roll * 0.55
        case .deadwood:
            return 0.55 + roll * 0.42
        case .crystal:
            return 0.55 + roll * 0.45
        }
    }

    private func chunkSeed(for coordinate: ChunkCoordinate, biomeType: BiomeType) -> UInt64 {
        StableHash.make { builder in
            builder.combine(seed)
            builder.combine(SeedDomain.props)
            builder.combine(coordinate)
            builder.combine(biomeSalt(for: biomeType))
        }.value
    }

    private func biomeSalt(for type: BiomeType) -> UInt64 {
        switch type {
        case .grassland:
            return 0x1000_0000_0000_0001
        case .temperateForest:
            return 0x2000_0000_0000_0002
        case .mountain:
            return 0x3000_0000_0000_0003
        case .desert:
            return 0x4000_0000_0000_0004
        case .marsh:
            return 0x5000_0000_0000_0005
        case .taiga:
            return 0x6000_0000_0000_0006
        case .coast:
            return 0x7000_0000_0000_0007
        case .freshwater:
            return 0x8000_0000_0000_0008
        }
    }

    private func randomUnit(_ random: inout StableRNG) -> Float {
        random.nextUnitFloat()
    }
}
