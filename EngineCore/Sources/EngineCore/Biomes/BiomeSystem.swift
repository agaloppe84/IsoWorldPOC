public enum BiomeDebugLayer: String, CaseIterable, Codable, Sendable {
    case temperature
    case humidity
    case altitude
    case continentality
    case distanceToWater
    case primaryBiomeWeight
    case secondaryBiomeWeight
    case ecotone
}

public struct BiomeSystem: Sendable {
    public let seed: WorldSeed
    public let biomeDNA: WorldBiomeDNA
    public let ruleSet: BiomeRuleSet
    public let ecotoneRules: [EcotoneRule]

    public init(
        seed: WorldSeed,
        biomeDNA: WorldBiomeDNA? = nil,
        ruleSet: BiomeRuleSet? = nil,
        ecotoneRules: [EcotoneRule] = EcotoneRule.defaultRules
    ) {
        let dna = biomeDNA ?? WorldBiomeDNA.make(worldSeed: seed)

        self.seed = seed
        self.biomeDNA = dna
        self.ruleSet = ruleSet ?? BiomeRuleSet(transitionSharpness: dna.transitionSharpness)
        self.ecotoneRules = ecotoneRules
    }

    public func biome(at position: WorldPosition) -> Biome {
        Biome.definition(for: biomeWeights(at: position).primaryBiomeType)
    }

    public func biomeWeights(at position: WorldPosition) -> BiomeWeights {
        ruleSet.biomeWeights(for: climate(at: position))
    }

    public func climate(at position: WorldPosition) -> ClimateSample {
        let elevation = valueNoise(x: position.x, z: position.z, cellSize: 128, salt: 0xE1E9_A710)
        let moisture = valueNoise(x: position.x, z: position.z, cellSize: 96, salt: 0xB10A_B10A)
        let temperature = valueNoise(x: position.x, z: position.z, cellSize: 160, salt: 0x7E2A_C011)
        let continentalness = valueNoise(x: position.x, z: position.z, cellSize: 224, salt: 0xC047_1A7D)
        let riverDistance = abs(valueNoise(x: position.x, z: position.z, cellSize: 72, salt: 0xF00D_4A7E))
        let waterBasin = 1 - normalized01(valueNoise(x: position.x, z: position.z, cellSize: 320, salt: 0x0CEA_0001))
        let distanceToWater = min(max(riverDistance * 0.85 + waterBasin * 0.15, 0), 1)

        return ClimateSample(
            elevation: elevation,
            moisture: min(max(moisture + biomeDNA.moistureBias, -1), 1),
            temperature: min(max(temperature + biomeDNA.temperatureBias - position.y * 0.015, -1), 1),
            continentalness: continentalness,
            altitude: min(max(position.y / 8, -1), 1),
            slope: 0,
            distanceToWater: distanceToWater
        )
    }

    public func climate(
        at position: WorldPosition,
        terrainSample: TerrainSample
    ) -> ClimateSample {
        let base = climate(at: position)

        return ClimateSample(
            elevation: base.elevation,
            moisture: base.moisture,
            temperature: base.temperature,
            continentalness: base.continentalness,
            altitude: min(max(terrainSample.height / 8, -1), 1),
            slope: min(max(terrainSample.slope / 2.5, 0), 1),
            distanceToWater: base.distanceToWater
        )
    }

    public func biomeWeights(
        at position: WorldPosition,
        terrainSample: TerrainSample
    ) -> BiomeWeights {
        ruleSet.biomeWeights(for: climate(at: position, terrainSample: terrainSample))
    }

    public func chunkData(
        for coordinate: ChunkCoordinate,
        terrainSystem: TerrainSystem,
        resolution: Int = ChunkHeightmap.resolution
    ) -> BiomeChunkData {
        var samples: [BiomeChunkSample] = []
        samples.reserveCapacity(resolution * resolution)

        for localZ in 0..<resolution {
            for localX in 0..<resolution {
                let terrainSample = terrainSystem.sample(
                    localX: localX,
                    localZ: localZ,
                    in: coordinate
                )
                let position = WorldPosition(
                    x: Float(terrainSample.worldX),
                    y: terrainSample.height,
                    z: Float(terrainSample.worldZ)
                )
                let climateSample = climate(at: position, terrainSample: terrainSample)
                let weights = ruleSet.biomeWeights(for: climateSample)

                samples.append(BiomeChunkSample(
                    localX: localX,
                    localZ: localZ,
                    worldX: terrainSample.worldX,
                    worldZ: terrainSample.worldZ,
                    climate: climateSample,
                    weights: weights,
                    ecotoneRule: ecotoneRule(for: weights)
                ))
            }
        }

        return BiomeChunkData(
            seed: seed,
            coordinate: coordinate,
            resolution: resolution,
            samples: samples
        )
    }

    public func debugValue(
        _ layer: BiomeDebugLayer,
        sample: BiomeChunkSample
    ) -> Float {
        switch layer {
        case .temperature:
            normalized01(sample.climate.temperature)
        case .humidity:
            normalized01(sample.climate.humidity)
        case .altitude:
            normalized01(sample.climate.altitude)
        case .continentality:
            normalized01(sample.climate.continentality)
        case .distanceToWater:
            1 - sample.climate.distanceToWater
        case .primaryBiomeWeight:
            sample.weights.primaryWeight
        case .secondaryBiomeWeight:
            sample.weights.secondaryWeight
        case .ecotone:
            sample.isEcotone ? 1 : 0
        }
    }

    public func ecotoneRule(for weights: BiomeWeights) -> EcotoneRule? {
        guard weights.secondaryWeight > 0 else {
            return nil
        }

        return ecotoneRules.first {
            $0.matches(weights.primaryBiomeType, weights.secondaryBiomeType)
        }
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
        var random = StableRNG(seedValue: latticeSeed(cellX: cellX, cellZ: cellZ, salt: salt))
        return random.nextUnitFloat() * 2.0 - 1.0
    }

    private func latticeSeed(cellX: Int, cellZ: Int, salt: UInt64) -> UInt64 {
        StableHash.make { builder in
            builder.combine(seed)
            builder.combine(SeedDomain.climate)
            builder.combine(biomeDNA.climateSeed)
            builder.combine(salt)
            builder.combine(cellX)
            builder.combine(cellZ)
        }.value
    }

    private func smoothStep(_ value: Float) -> Float {
        value * value * (3.0 - 2.0 * value)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }

    private func normalized01(_ value: Float) -> Float {
        min(max(value * 0.5 + 0.5, 0), 1)
    }
}
