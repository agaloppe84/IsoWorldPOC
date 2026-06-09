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

        var random = SeededRandom(seedValue: chunkSeed(for: coordinate, biomeType: biome.type))
        let count = targetPropCount(for: biome.type, random: &random)
        let clampedCount = min(count, maxPropsPerChunk)
        let maxLocalPosition = Float(samplesPerChunk - 1)
        let margin = min(Float(2), maxLocalPosition * 0.25)
        let usableSpan = max(Float(0), maxLocalPosition - margin * 2)

        return (0..<clampedCount).map { _ in
            let type = propType(for: biome.type, roll: randomUnit(&random))
            let localX = margin + randomUnit(&random) * usableSpan
            let localZ = margin + randomUnit(&random) * usableSpan
            let worldX = Float(coordinate.x * samplesPerChunk) + localX
            let worldZ = Float(coordinate.z * samplesPerChunk) + localZ

            return PropPlacement(
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

    private func targetPropCount(for biomeType: BiomeType, random: inout SeededRandom) -> Int {
        let baseCount: Int
        let jitterRange: Int

        switch biomeType {
        case .plain:
            baseCount = 4
            jitterRange = 2
        case .forest:
            baseCount = 15
            jitterRange = 4
        case .rocky:
            baseCount = 10
            jitterRange = 3
        case .highlands:
            baseCount = 7
            jitterRange = 3
        }

        let jitter = Int(random.next() % UInt64(jitterRange + 1))
        return baseCount + jitter
    }

    private func propType(for biomeType: BiomeType, roll: Float) -> PropType {
        switch biomeType {
        case .plain:
            if roll < 0.55 { return .rock }
            if roll < 0.90 { return .treePlaceholder }
            return .crystalPlaceholder
        case .forest:
            if roll < 0.72 { return .treePlaceholder }
            if roll < 0.94 { return .rock }
            return .crystalPlaceholder
        case .rocky:
            if roll < 0.72 { return .rock }
            if roll < 0.92 { return .crystalPlaceholder }
            return .treePlaceholder
        case .highlands:
            if roll < 0.52 { return .rock }
            if roll < 0.78 { return .crystalPlaceholder }
            return .treePlaceholder
        }
    }

    private func scale(for type: PropType, random: inout SeededRandom) -> Float {
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
        var value = seed.value ^ 0x51A7_7E11_9A5B_2026
        value = mix(value, with: coordinate.x)
        value = mix(value, with: coordinate.y)
        value = mix(value, with: coordinate.z)
        value ^= biomeSalt(for: biomeType)
        return value
    }

    private func biomeSalt(for type: BiomeType) -> UInt64 {
        switch type {
        case .plain:
            return 0x1000_0000_0000_0001
        case .forest:
            return 0x2000_0000_0000_0002
        case .rocky:
            return 0x3000_0000_0000_0003
        case .highlands:
            return 0x4000_0000_0000_0004
        }
    }

    private func mix(_ current: UInt64, with value: Int) -> UInt64 {
        var mixed = current ^ UInt64(bitPattern: Int64(value))
        mixed &*= 0x9E37_79B9_7F4A_7C15
        mixed ^= mixed >> 30
        mixed &*= 0xBF58_476D_1CE4_E5B9
        mixed ^= mixed >> 27
        mixed &*= 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    private func randomUnit(_ random: inout SeededRandom) -> Float {
        let value = random.next() >> 40
        return Float(value) / Float(0x00ff_ffff)
    }
}
