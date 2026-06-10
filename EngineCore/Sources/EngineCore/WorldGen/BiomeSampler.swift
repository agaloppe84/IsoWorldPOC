public struct BiomeSampler: Sendable {
    public let seed: WorldSeed
    public let ruleSet: BiomeRuleSet

    public init(seed: WorldSeed, ruleSet: BiomeRuleSet = BiomeRuleSet()) {
        self.seed = seed
        self.ruleSet = ruleSet
    }

    public func biome(at position: WorldPosition) -> Biome {
        let type = ruleSet.biomeType(for: climate(at: position))
        return Biome.definition(for: type)
    }

    public func climate(at position: WorldPosition) -> ClimateSample {
        ClimateSample(
            elevation: valueNoise(x: position.x, z: position.z, cellSize: 128, salt: 0xE1E9_A710),
            moisture: valueNoise(x: position.x, z: position.z, cellSize: 96, salt: 0xB10A_B10A),
            temperature: valueNoise(x: position.x, z: position.z, cellSize: 160, salt: 0x7E2A_C011),
            continentalness: valueNoise(x: position.x, z: position.z, cellSize: 224, salt: 0xC047_1A7D)
        )
    }

    public func biome(
        for coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        samplesPerChunk: Int = 64
    ) -> Biome {
        precondition(samplesPerChunk > 0, "samplesPerChunk must be positive.")
        let sampleStride = max(samplesPerChunk - 1, 1)

        let position = WorldPosition(
            x: Float(coordinate.x * sampleStride + localX),
            y: Float(coordinate.y * sampleStride),
            z: Float(coordinate.z * sampleStride + localZ)
        )

        return biome(at: position)
    }

    public func dominantBiome(
        for coordinate: ChunkCoordinate,
        samplesPerChunk: Int = 64
    ) -> Biome {
        biome(
            for: coordinate,
            localX: samplesPerChunk / 2,
            localZ: samplesPerChunk / 2,
            samplesPerChunk: samplesPerChunk
        )
    }

    private func valueNoise(x: Float, z: Float, cellSize: Int, salt: UInt64) -> Float {
        let scaledX = Int((x / Float(cellSize)).rounded(.down))
        let scaledZ = Int((z / Float(cellSize)).rounded(.down))
        let fractionX = positiveFraction(x, cellSize: cellSize)
        let fractionZ = positiveFraction(z, cellSize: cellSize)

        let v00 = latticeValue(cellX: scaledX, cellZ: scaledZ, salt: salt)
        let v10 = latticeValue(cellX: scaledX + 1, cellZ: scaledZ, salt: salt)
        let v01 = latticeValue(cellX: scaledX, cellZ: scaledZ + 1, salt: salt)
        let v11 = latticeValue(cellX: scaledX + 1, cellZ: scaledZ + 1, salt: salt)
        let smoothX = smoothStep(fractionX)
        let smoothZ = smoothStep(fractionZ)

        return lerp(
            lerp(v00, v10, smoothX),
            lerp(v01, v11, smoothX),
            smoothZ
        )
    }

    private func positiveFraction(_ value: Float, cellSize: Int) -> Float {
        let cell = Float(cellSize)
        let remainder = value - (value / cell).rounded(.down) * cell

        return remainder / cell
    }

    private func latticeValue(cellX: Int, cellZ: Int, salt: UInt64) -> Float {
        var random = SeededRandom(seedValue: latticeSeed(cellX: cellX, cellZ: cellZ, salt: salt))
        let value = random.next() >> 40
        let unit = Float(value) / Float(0x00ff_ffff)

        return unit * 2.0 - 1.0
    }

    private func latticeSeed(cellX: Int, cellZ: Int, salt: UInt64) -> UInt64 {
        var value = seed.value ^ salt
        value = mix(value, with: cellX)
        value = mix(value, with: cellZ)
        return value
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

    private func smoothStep(_ value: Float) -> Float {
        value * value * (3.0 - 2.0 * value)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}
