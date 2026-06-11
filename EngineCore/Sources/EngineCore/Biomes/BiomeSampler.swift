public struct BiomeSampler: Sendable {
    public let seed: WorldSeed
    public let system: BiomeSystem

    public init(seed: WorldSeed, ruleSet: BiomeRuleSet = BiomeRuleSet()) {
        self.seed = seed
        self.system = BiomeSystem(seed: seed, ruleSet: ruleSet)
    }

    public func biome(at position: WorldPosition) -> Biome {
        system.biome(at: position)
    }

    public func climate(at position: WorldPosition) -> ClimateSample {
        system.climate(at: position)
    }

    public func biomeWeights(at position: WorldPosition) -> BiomeWeights {
        system.biomeWeights(at: position)
    }

    public func biome(
        for coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        samplesPerChunk: Int = 64
    ) -> Biome {
        biome(at: samplePosition(
            for: coordinate,
            localX: localX,
            localZ: localZ,
            samplesPerChunk: samplesPerChunk
        ))
    }

    public func terrainVertexMaterial(
        for coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        samplesPerChunk: Int = 64
    ) -> TerrainVertexMaterial {
        terrainVertexMaterial(at: samplePosition(
            for: coordinate,
            localX: localX,
            localZ: localZ,
            samplesPerChunk: samplesPerChunk
        ))
    }

    public func terrainMaterialSplat(
        for coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        samplesPerChunk: Int = 64
    ) -> TerrainMaterialSplat {
        terrainMaterialSplat(at: samplePosition(
            for: coordinate,
            localX: localX,
            localZ: localZ,
            samplesPerChunk: samplesPerChunk
        ))
    }

    public func terrainVertexMaterial(at position: WorldPosition) -> TerrainVertexMaterial {
        let primaryBiome = biome(at: position)
        let splat = terrainMaterialSplat(at: position, primaryBiome: primaryBiome)

        return TerrainVertexMaterial(
            primaryBiome: primaryBiome,
            splat: splat
        )
    }

    public func terrainMaterialSplat(at position: WorldPosition) -> TerrainMaterialSplat {
        let primaryBiome = biome(at: position)

        return terrainMaterialSplat(at: position, primaryBiome: primaryBiome)
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

    private func samplePosition(
        for coordinate: ChunkCoordinate,
        localX: Int,
        localZ: Int,
        samplesPerChunk: Int
    ) -> WorldPosition {
        precondition(samplesPerChunk > 0, "samplesPerChunk must be positive.")
        let sampleStride = max(samplesPerChunk - 1, 1)

        return WorldPosition(
            x: Float(coordinate.x * sampleStride + localX),
            y: Float(coordinate.y * sampleStride),
            z: Float(coordinate.z * sampleStride + localZ)
        )
    }

    private func terrainMaterialSplat(
        at position: WorldPosition,
        primaryBiome: Biome
    ) -> TerrainMaterialSplat {
        let weights = system.biomeWeights(at: position)

        guard weights.secondaryWeight > 0.0001 else {
            return TerrainMaterialSplat(biome: primaryBiome)
        }

        var layers = [
            TerrainMaterialSplatLayer(
                biome: primaryBiome,
                weight: 1 - min(weights.secondaryWeight, 0.45)
            )
        ]

        if let secondaryLayer = weights.secondaryLayer {
            layers.append(TerrainMaterialSplatLayer(
                biome: secondaryLayer.biome,
                weight: min(secondaryLayer.weight, 0.45)
            ))
        }

        return TerrainMaterialSplat(layers: layers)
    }
}
