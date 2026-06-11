public struct PropSystem: Sendable {
    public let seed: WorldSeed
    public let catalog: PropCatalog
    public let maxPropsPerChunk: Int

    private let assetGenerator: ProceduralAssetGenerator

    public init(
        seed: WorldSeed,
        catalog: PropCatalog = .naturalV1,
        maxPropsPerChunk: Int = PropPlacementGenerator.defaultMaxPropsPerChunk
    ) {
        precondition(maxPropsPerChunk >= 0, "maxPropsPerChunk must be zero or positive.")

        self.seed = seed
        self.catalog = catalog
        self.maxPropsPerChunk = maxPropsPerChunk
        self.assetGenerator = ProceduralAssetGenerator(seed: seed)
    }

    public func placements(
        for coordinate: ChunkCoordinate,
        biome: Biome,
        terrainSampleGrid: TerrainSampleGrid
    ) -> [PropPlacement] {
        chunkData(
            for: coordinate,
            biome: biome,
            terrainSampleGrid: terrainSampleGrid
        ).placements
    }

    public func chunkData(
        for coordinate: ChunkCoordinate,
        biome: Biome,
        terrainSampleGrid: TerrainSampleGrid
    ) -> PropChunkData {
        precondition(
            terrainSampleGrid.coordinate == coordinate,
            "PropSystem terrain grid must match the requested chunk coordinate."
        )

        guard maxPropsPerChunk > 0 else {
            return PropChunkData(coordinate: coordinate, biome: biome, recipes: [], variants: [])
        }

        var random = StableRNG(seedValue: chunkSeed(for: coordinate, biomeType: biome.type))
        let targetCount = min(targetPropCount(for: biome, grid: terrainSampleGrid, random: &random), maxPropsPerChunk)
        let maxAttempts = max(maxPropsPerChunk * 3, targetCount * 5)
        let maxLocalPosition = Float(terrainSampleGrid.resolution - 1)
        let margin = min(Float(2), maxLocalPosition * 0.25)
        let usableSpan = max(Float(0), maxLocalPosition - margin * 2)
        var recipes: [PropRecipe] = []
        var variants: [PropVariant] = []

        recipes.reserveCapacity(targetCount)
        variants.reserveCapacity(targetCount)

        for _ in 0..<maxAttempts where recipes.count < targetCount {
            let localX = margin + random.nextUnitFloat() * usableSpan
            let localZ = margin + random.nextUnitFloat() * usableSpan
            let sample = nearestSample(localX: localX, localZ: localZ, in: terrainSampleGrid)
            let context = PropContext(
                worldSeed: seed,
                coordinate: coordinate,
                biome: biome,
                localX: localX,
                localZ: localZ,
                terrainSample: sample
            )

            guard let type = catalog.chooseType(in: context, random: &random) else {
                continue
            }

            let placementIndex = recipes.count
            let placement = PropPlacement(
                placementIndex: placementIndex,
                type: type,
                localX: localX,
                localZ: localZ,
                worldX: Float(coordinate.x * ChunkHeightmap.gridStride) + localX,
                worldZ: Float(coordinate.z * ChunkHeightmap.gridStride) + localZ,
                rotationRadians: random.nextUnitFloat() * Float.pi * 2,
                scale: scale(for: type, context: context, random: &random)
            )
            let stableID = StableID.prop(
                worldSeed: seed,
                coordinate: coordinate,
                placementIndex: placementIndex
            )
            let archetype = PropArchetype.definition(for: type, biome: biome)
            let genome = PropVariantGenome.make(
                stableID: stableID,
                worldSeed: seed,
                coordinate: coordinate,
                placement: placement
            )
            let recipe = PropRecipe(
                stableID: stableID,
                placement: placement,
                biomeType: biome.type,
                archetypeID: archetype.identifier,
                context: context,
                genome: genome
            )
            let variant = assetGenerator.variant(
                for: placement,
                biome: biome,
                chunk: coordinate
            )

            recipes.append(recipe)
            variants.append(variant)
        }

        return PropChunkData(
            coordinate: coordinate,
            biome: biome,
            recipes: recipes,
            variants: variants
        )
    }

    private func targetPropCount(
        for biome: Biome,
        grid: TerrainSampleGrid,
        random: inout StableRNG
    ) -> Int {
        let baseCount: Int
        let jitterRange: Int

        switch biome.type {
        case .grassland:
            baseCount = 14
            jitterRange = 6
        case .temperateForest:
            baseCount = 24
            jitterRange = 8
        case .mountain:
            baseCount = 14
            jitterRange = 5
        case .desert:
            baseCount = 9
            jitterRange = 4
        case .marsh:
            baseCount = 18
            jitterRange = 6
        case .taiga:
            baseCount = 20
            jitterRange = 7
        case .coast:
            baseCount = 11
            jitterRange = 4
        case .freshwater:
            baseCount = 9
            jitterRange = 3
        }

        let jitter = Int(random.next() % UInt64(jitterRange + 1))
        let walkableRatio = Float(grid.samples.filter { $0.walkability >= 0.35 }.count) /
            Float(grid.samples.count)
        let terrainMultiplier = 0.75 + walkableRatio * 0.45
        let densityAdjusted = Float(baseCount + jitter) * biome.propDensityMultiplier * terrainMultiplier

        return max(0, Int(densityAdjusted.rounded()))
    }

    private func scale(
        for type: PropType,
        context: PropContext,
        random: inout StableRNG
    ) -> Float {
        let roll = random.nextUnitFloat()
        let slopeCompression = 1 - min(context.slope * 0.12, 0.18)

        switch type {
        case .rock:
            return (0.72 + roll * 0.72) * slopeCompression
        case .pebble:
            return 0.30 + roll * 0.34
        case .grass:
            return 0.46 + roll * 0.44
        case .tree:
            return (0.86 + roll * 0.62) * slopeCompression
        case .deadwood:
            return 0.58 + roll * 0.46
        case .crystal:
            return 0.55 + roll * 0.48
        }
    }

    private func nearestSample(
        localX: Float,
        localZ: Float,
        in grid: TerrainSampleGrid
    ) -> TerrainSample {
        let x = clamped(Int(localX.rounded()), lowerBound: 0, upperBound: grid.resolution - 1)
        let z = clamped(Int(localZ.rounded()), lowerBound: 0, upperBound: grid.resolution - 1)

        return grid.sample(localX: x, localZ: z)
    }

    private func clamped(_ value: Int, lowerBound: Int, upperBound: Int) -> Int {
        min(max(value, lowerBound), upperBound)
    }

    private func chunkSeed(for coordinate: ChunkCoordinate, biomeType: BiomeType) -> UInt64 {
        StableHash.make { builder in
            builder.combine(seed)
            builder.combine(SeedDomain.props)
            builder.combine(coordinate)
            builder.combine(biomeType.rawValue)
            builder.combine(catalog.identifier)
        }.value
    }
}
