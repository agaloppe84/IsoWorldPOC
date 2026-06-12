import Foundation

public struct SettlementSystem: Sendable {
    public let worldSeed: WorldSeed
    public let generatorVersions: GeneratorVersionTable

    public init(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) {
        self.worldSeed = worldSeed
        self.generatorVersions = generatorVersions
    }

    public func plan(
        for coordinate: ChunkCoordinate,
        terrainSampleGrid: TerrainSampleGrid,
        ruleset: WorldRuleset
    ) -> SettlementPlan {
        precondition(
            terrainSampleGrid.coordinate == coordinate,
            "SettlementSystem terrain grid must match the requested chunk coordinate."
        )

        let supportMap = TerrainSupportMap(grid: terrainSampleGrid)
        let biome = Biome.definition(for: supportMap.dominantBiomeType)
        let recipe = SettlementRecipe.makeV1(
            worldSeed: worldSeed,
            ruleset: ruleset,
            biomeType: supportMap.dominantBiomeType,
            generatorVersions: generatorVersions
        )
        let site = SettlementSiteSelector(
            worldSeed: worldSeed,
            generatorVersions: generatorVersions
        ).selectSite(
            supportMap: supportMap,
            recipe: recipe,
            ruleset: ruleset
        )
        let intents = buildingIntents(
            recipe: recipe,
            site: site,
            supportMap: supportMap
        )
        let footprintGenerator = FootprintGenerator(
            worldSeed: worldSeed,
            generatorVersions: generatorVersions
        )
        let massingGenerator = MassingGenerator(
            worldSeed: worldSeed,
            generatorVersions: generatorVersions
        )
        let recipeByID = Dictionary(
            uniqueKeysWithValues: recipe.buildingDistribution.map { weighted in
                (weighted.recipe.id, weighted.recipe)
            }
        )
        let buildings = intents.map { intent -> SettlementBuilding in
            let structure = recipeByID[intent.structureRecipeID] ?? StructureRecipe.v1Catalog[0]
            let footprint = footprintGenerator.footprint(
                for: intent,
                structureRecipe: structure,
                supportMap: supportMap
            )
            let massing = massingGenerator.massing(
                for: intent,
                structureRecipe: structure,
                footprint: footprint,
                biome: biome,
                ruleset: ruleset
            )

            return SettlementBuilding(
                intent: intent,
                footprint: footprint,
                massing: massing
            )
        }
        let paths = pathSegments(
            site: site,
            recipe: recipe,
            buildings: buildings,
            supportMap: supportMap
        )

        return SettlementPlan(
            worldSeed: worldSeed,
            coordinate: coordinate,
            site: site,
            recipe: recipe,
            buildings: buildings,
            paths: paths,
            renderInstances: buildings.map(\.massing.renderInstance)
        )
    }

    private func buildingIntents(
        recipe: SettlementRecipe,
        site: SettlementSiteCandidate,
        supportMap: TerrainSupportMap
    ) -> [BuildingIntent] {
        var rng = StableRNG(seedValue: StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.buildingIntents)
            builder.combine(generatorVersions.version(for: .buildingIntents))
            builder.combine(site.id.rawValue)
            builder.combine(recipe.id)
        }.value)
        var intents: [BuildingIntent] = []
        intents.reserveCapacity(recipe.desiredBuildingCount)

        for index in 0..<recipe.desiredBuildingCount {
            let structure = requiredStructure(
                index: index,
                recipe: recipe,
                rng: &rng
            )
            let placement = localPlacement(
                index: index,
                count: recipe.desiredBuildingCount,
                radius: site.buildableRadius,
                centerX: site.localCenterX,
                centerZ: site.localCenterZ,
                supportMap: supportMap,
                rng: &rng
            )
            let intent = BuildingIntent.makeV1(
                worldSeed: worldSeed,
                settlementID: site.id,
                index: index,
                structureRecipe: structure,
                localAnchorX: placement.x,
                localAnchorZ: placement.z,
                rotationRadians: placement.rotation,
                generatorVersions: generatorVersions,
                rng: &rng
            )

            intents.append(intent)
        }

        return intents
    }

    private func requiredStructure(
        index: Int,
        recipe: SettlementRecipe,
        rng: inout StableRNG
    ) -> StructureRecipe {
        let catalog = recipe.buildingDistribution.map(\.recipe)

        if index == 0 {
            return catalog.first { $0.function == .hall } ??
                catalog.first { $0.function == .market } ??
                catalog.first { $0.function == .shrine } ??
                catalog.first { $0.function == .dwelling } ??
                recipe.chooseStructureRecipe(using: &rng)
        }

        if index == 1 {
            return catalog.first { $0.function == .dwelling } ??
                recipe.chooseStructureRecipe(using: &rng)
        }

        return recipe.chooseStructureRecipe(using: &rng)
    }

    private func localPlacement(
        index: Int,
        count: Int,
        radius: Float,
        centerX: Float,
        centerZ: Float,
        supportMap: TerrainSupportMap,
        rng: inout StableRNG
    ) -> (x: Float, z: Float, rotation: Float) {
        if index == 0 {
            return (centerX, centerZ, rng.nextFloat(in: 0...(Float.pi * 2)))
        }

        let angle = (Float(index) / Float(max(count, 1))) * Float.pi * 2 +
            rng.nextFloat(in: (-0.26)...0.26)
        let ring = radius * rng.nextFloat(in: 0.35...0.92)
        let localX = centerX + cos(angle) * ring
        let localZ = centerZ + sin(angle) * ring
        let maxLocal = Float(supportMap.resolution - 1)
        let x = clamped(localX, lowerBound: 4, upperBound: maxLocal - 4)
        let z = clamped(localZ, lowerBound: 4, upperBound: maxLocal - 4)
        let rotation = atan2(centerX - x, centerZ - z)

        return (x, z, rotation)
    }

    private func pathSegments(
        site: SettlementSiteCandidate,
        recipe: SettlementRecipe,
        buildings: [SettlementBuilding],
        supportMap: TerrainSupportMap
    ) -> [SettlementPathSegment] {
        buildings.enumerated().compactMap { index, building in
            guard index > 0 else {
                return nil
            }

            let startSample = supportMap.nearestSample(
                localX: site.localCenterX,
                localZ: site.localCenterZ
            )
            let endSample = supportMap.nearestSample(
                localX: building.footprint.centerLocalX,
                localZ: building.footprint.centerLocalZ
            )
            let id = StableID.make(
                worldSeed: worldSeed,
                domain: .settlements,
                coordinate: site.coordinate,
                values: [
                    versionValue(for: .settlements),
                    site.id.rawValue,
                    building.intent.id.rawValue,
                    UInt64(bitPattern: Int64(index)),
                ]
            )

            return SettlementPathSegment(
                id: id,
                kind: recipe.pathKind,
                start: WorldPosition(
                    x: site.worldCenter.x,
                    y: startSample.height,
                    z: site.worldCenter.z
                ),
                end: WorldPosition(
                    x: building.footprint.centerWorld.x,
                    y: endSample.height,
                    z: building.footprint.centerWorld.z
                ),
                width: pathWidth(for: recipe.pathKind),
                slopeCost: abs(startSample.height - endSample.height) /
                    max(distance(start: startSample, end: endSample), 1)
            )
        }
    }

    private func pathWidth(for kind: SettlementPathKind) -> Float {
        switch kind {
        case .footpath:
            return 1.2
        case .boardwalk:
            return 1.6
        case .switchback:
            return 1.4
        case .stonePath:
            return 1.8
        }
    }

    private func distance(
        start: TerrainSupportSample,
        end: TerrainSupportSample
    ) -> Float {
        let dx = Float(end.worldX - start.worldX)
        let dz = Float(end.worldZ - start.worldZ)
        return (dx * dx + dz * dz).squareRoot()
    }

    private func versionValue(for domain: SeedDomain) -> UInt64 {
        StableHash.make { builder in
            builder.combine(domain)
            builder.combine(generatorVersions.version(for: domain))
        }.value
    }
}

private func clamped(_ value: Float, lowerBound: Float, upperBound: Float) -> Float {
    min(max(value, lowerBound), upperBound)
}
