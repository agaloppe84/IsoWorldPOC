public struct SettlementSiteCandidate: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let coordinate: ChunkCoordinate
    public let localCenterX: Float
    public let localCenterZ: Float
    public let worldCenter: WorldPosition
    public let biomeType: BiomeType
    public let supportSolution: TerrainSupportSolution
    public let buildableRadius: Float
    public let score: Float
    public let waterAccess: Float
    public let tags: [GameplayTag]

    public init(
        id: StableID,
        coordinate: ChunkCoordinate,
        localCenterX: Float,
        localCenterZ: Float,
        worldCenter: WorldPosition,
        biomeType: BiomeType,
        supportSolution: TerrainSupportSolution,
        buildableRadius: Float,
        score: Float,
        waterAccess: Float,
        tags: [GameplayTag]
    ) {
        self.id = id
        self.coordinate = coordinate
        self.localCenterX = localCenterX
        self.localCenterZ = localCenterZ
        self.worldCenter = worldCenter
        self.biomeType = biomeType
        self.supportSolution = supportSolution
        self.buildableRadius = max(buildableRadius, 1)
        self.score = clamped01(score)
        self.waterAccess = clamped01(waterAccess)
        self.tags = tags.uniquedStable()
    }
}

public struct SettlementSiteSelector: Sendable {
    public let worldSeed: WorldSeed
    public let generatorVersions: GeneratorVersionTable

    public init(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) {
        self.worldSeed = worldSeed
        self.generatorVersions = generatorVersions
    }

    public func candidates(
        supportMap: TerrainSupportMap,
        recipe: SettlementRecipe,
        ruleset: WorldRuleset,
        maxCandidates: Int = 24
    ) -> [SettlementSiteCandidate] {
        precondition(maxCandidates >= 0, "maxCandidates must be non-negative.")

        guard maxCandidates > 0 else {
            return []
        }

        var rng = StableRNG(seedValue: seedValue(
            coordinate: supportMap.coordinate,
            recipeID: recipe.id
        ))
        let margin = min(max(recipe.radius * 0.55, 5), Float(supportMap.resolution - 1) * 0.34)
        let maxLocal = Float(supportMap.resolution - 1)
        var candidates: [SettlementSiteCandidate] = []
        candidates.reserveCapacity(maxCandidates)

        for index in 0..<(maxCandidates * 3) where candidates.count < maxCandidates {
            let localX = rng.nextFloat(in: margin...(maxLocal - margin))
            let localZ = rng.nextFloat(in: margin...(maxLocal - margin))
            let sample = supportMap.nearestSample(localX: localX, localZ: localZ)

            guard sample.slope <= recipe.maxSlope || recipe.allowedSupportSolutions.contains(sample.supportSolution) else {
                continue
            }

            let candidate = makeCandidate(
                index: index,
                sample: sample,
                localX: localX,
                localZ: localZ,
                supportMap: supportMap,
                recipe: recipe,
                ruleset: ruleset,
                jitter: rng.nextFloat(in: 0...0.025)
            )

            if candidate.score >= 0.30 {
                candidates.append(candidate)
            }
        }

        if candidates.isEmpty, let fallback = supportMap.bestBuildableSamples(limit: 1).first {
            candidates.append(makeCandidate(
                index: 0,
                sample: fallback,
                localX: Float(fallback.localX),
                localZ: Float(fallback.localZ),
                supportMap: supportMap,
                recipe: recipe,
                ruleset: ruleset,
                jitter: 0
            ))
        }

        return candidates.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }

            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    public func selectSite(
        supportMap: TerrainSupportMap,
        recipe: SettlementRecipe,
        ruleset: WorldRuleset
    ) -> SettlementSiteCandidate {
        if let best = candidates(
            supportMap: supportMap,
            recipe: recipe,
            ruleset: ruleset
        ).first {
            return best
        }

        let center = supportMap.nearestSample(
            localX: Float(supportMap.resolution - 1) * 0.5,
            localZ: Float(supportMap.resolution - 1) * 0.5
        )

        return makeCandidate(
            index: 0,
            sample: center,
            localX: Float(center.localX),
            localZ: Float(center.localZ),
            supportMap: supportMap,
            recipe: recipe,
            ruleset: ruleset,
            jitter: 0
        )
    }

    private func makeCandidate(
        index: Int,
        sample: TerrainSupportSample,
        localX: Float,
        localZ: Float,
        supportMap: TerrainSupportMap,
        recipe: SettlementRecipe,
        ruleset: WorldRuleset,
        jitter: Float
    ) -> SettlementSiteCandidate {
        let slopeCompatibility = 1 - min(sample.slope / max(recipe.maxSlope, 0.01), 1)
        let waterAccess = localWaterAccess(sample: sample, supportMap: supportMap)
        let biomeCompatibility = biomeCompatibility(
            biomeType: sample.biomeType,
            recipe: recipe,
            ruleset: ruleset
        )
        let supportBonus: Float = recipe.allowedSupportSolutions.contains(sample.supportSolution) ? 0.08 : -0.10
        let score = sample.buildableScore * 0.50 +
            slopeCompatibility * 0.16 +
            waterAccess * recipe.waterNeed * 0.16 +
            biomeCompatibility * 0.12 +
            ruleset.dna.factionDensity * recipe.tradeNeed * 0.04 +
            supportBonus +
            jitter
        let id = StableID.make(
            worldSeed: worldSeed,
            domain: .settlementSites,
            coordinate: supportMap.coordinate,
            values: [
                versionValue(for: .settlementSites),
                UInt64(bitPattern: Int64(index)),
                StableHash.make { builder in
                    builder.combine(recipe.id)
                    builder.combine(sample.localX)
                    builder.combine(sample.localZ)
                }.value,
            ]
        )

        return SettlementSiteCandidate(
            id: id,
            coordinate: supportMap.coordinate,
            localCenterX: localX,
            localCenterZ: localZ,
            worldCenter: WorldPosition(
                x: Float(sample.worldX),
                y: sample.height,
                z: Float(sample.worldZ)
            ),
            biomeType: sample.biomeType,
            supportSolution: sample.supportSolution,
            buildableRadius: recipe.radius * (0.70 + sample.buildableScore * 0.45),
            score: score,
            waterAccess: waterAccess,
            tags: (recipe.tags + [.terrainAdapted]).uniquedStable()
        )
    }

    private func seedValue(
        coordinate: ChunkCoordinate,
        recipeID: String
    ) -> UInt64 {
        StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.settlementSites)
            builder.combine(generatorVersions.version(for: .settlementSites))
            builder.combine(coordinate)
            builder.combine(recipeID)
        }.value
    }

    private func versionValue(for domain: SeedDomain) -> UInt64 {
        StableHash.make { builder in
            builder.combine(domain)
            builder.combine(generatorVersions.version(for: domain))
        }.value
    }

    private func localWaterAccess(
        sample: TerrainSupportSample,
        supportMap: TerrainSupportMap
    ) -> Float {
        let direct = sample.waterDepth > 0 || sample.biomeType == .freshwater ? Float(1) : Float(0)
        let moist = sample.moisture > 0.58 ? sample.moisture : 0
        let coastal: Float = sample.biomeType == .coast || sample.biomeType == .marsh ? 0.78 : 0
        return max(direct, moist, coastal, supportMap.waterAccessScore * 0.65)
    }

    private func biomeCompatibility(
        biomeType: BiomeType,
        recipe: SettlementRecipe,
        ruleset: WorldRuleset
    ) -> Float {
        switch recipe.type {
        case .camp:
            return biomeType == .mountain || biomeType == .desert ? 0.82 : 0.66
        case .hamlet, .farmstead:
            return biomeType == .grassland || biomeType == .temperateForest ? 1 : 0.62
        case .tradePost:
            return biomeType == .coast || biomeType == .freshwater ? 1 : 0.72 + ruleset.dna.economyImportance * 0.18
        case .shrineCluster:
            return biomeType == .mountain || biomeType == .freshwater ? 0.92 : 0.70
        case .frontierOutpost:
            return biomeType == .mountain || biomeType == .taiga ? 0.90 : 0.68
        case .ruinCluster:
            return biomeType == .desert || biomeType == .mountain ? 0.88 : 0.72
        }
    }
}

private func clamped01(_ value: Float) -> Float {
    min(max(value, 0), 1)
}
