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

    private func targetPropCount(for biome: Biome, random: inout StableRNG) -> Int {
        let baseCount: Int
        let jitterRange: Int

        switch biome.type {
        case .grassland:
            baseCount = 4
            jitterRange = 2
        case .forest:
            baseCount = 15
            jitterRange = 4
        case .rockyHighlands:
            baseCount = 10
            jitterRange = 3
        case .dryPlateau:
            baseCount = 4
            jitterRange = 2
        case .wetValley:
            baseCount = 9
            jitterRange = 3
        }

        let jitter = Int(random.next() % UInt64(jitterRange + 1))
        let densityAdjusted = Float(baseCount + jitter) * biome.propDensityMultiplier

        return max(0, Int(densityAdjusted.rounded()))
    }

    private func propType(for biomeType: BiomeType, roll: Float) -> PropType {
        switch biomeType {
        case .grassland:
            if roll < 0.55 { return .rock }
            if roll < 0.90 { return .treePlaceholder }
            return .crystalPlaceholder
        case .forest:
            if roll < 0.72 { return .treePlaceholder }
            if roll < 0.94 { return .rock }
            return .crystalPlaceholder
        case .rockyHighlands:
            if roll < 0.72 { return .rock }
            if roll < 0.92 { return .crystalPlaceholder }
            return .treePlaceholder
        case .dryPlateau:
            if roll < 0.78 { return .rock }
            if roll < 0.96 { return .crystalPlaceholder }
            return .treePlaceholder
        case .wetValley:
            if roll < 0.58 { return .treePlaceholder }
            if roll < 0.88 { return .rock }
            return .crystalPlaceholder
        }
    }

    private func scale(for type: PropType, random: inout StableRNG) -> Float {
        let roll = randomUnit(&random)

        switch type {
        case .rock:
            return 0.65 + roll * 0.65
        case .treePlaceholder:
            return 0.85 + roll * 0.55
        case .crystalPlaceholder:
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
        case .forest:
            return 0x2000_0000_0000_0002
        case .rockyHighlands:
            return 0x3000_0000_0000_0003
        case .dryPlateau:
            return 0x4000_0000_0000_0004
        case .wetValley:
            return 0x5000_0000_0000_0005
        }
    }

    private func randomUnit(_ random: inout StableRNG) -> Float {
        random.nextUnitFloat()
    }
}
