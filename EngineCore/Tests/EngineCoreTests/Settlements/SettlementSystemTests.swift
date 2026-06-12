import XCTest
@testable import EngineCore

final class SettlementSystemTests: XCTestCase {
    func testSettlementSystemBuildsDeterministicCodablePlan() throws {
        let seed = WorldSeed(22_001)
        let ruleset = ruleset(seed: seed, dna: settlementDNA(seed: 1))
        let grid = sampleGrid(
            biome: .grassland,
            slope: 0.08,
            roughness: 0.16,
            moisture: 0.58,
            walkability: 0.92
        )
        let system = SettlementSystem(worldSeed: seed)

        let first = system.plan(for: .origin, terrainSampleGrid: grid, ruleset: ruleset)
        let second = system.plan(for: .origin, terrainSampleGrid: grid, ruleset: ruleset)
        let decoded = try JSONDecoder().decode(
            SettlementPlan.self,
            from: JSONEncoder().encode(first)
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, decoded)
        XCTAssertTrue(first.validationReport.isValid, first.validationReport.issues.joined(separator: ", "))
        XCTAssertEqual(first.buildings.count, first.recipe.desiredBuildingCount)
        XCTAssertEqual(first.renderInstances.count, first.buildings.count)
        XCTAssertTrue(first.debugSummary.contains("Settlement Plan"))
    }

    func testTerrainSupportMapClassifiesSlopeWaterAndBuildableRatio() {
        let grid = sampleGrid { localX, localZ in
            if localX < 16 {
                return SampleShape(slope: 0.04, waterDepth: 0, featureMasks: .zero, walkability: 0.98)
            }

            if localX < 32 {
                return SampleShape(slope: 0.20, waterDepth: 0, featureMasks: .zero, walkability: 0.82)
            }

            if localZ < 32 {
                return SampleShape(
                    slope: 0.10,
                    waterDepth: 0.20,
                    featureMasks: TerrainFeatureMasks(water: 0.7),
                    walkability: 0.55
                )
            }

            return SampleShape(
                slope: 0.70,
                waterDepth: 0,
                featureMasks: TerrainFeatureMasks(cliff: 0.8),
                walkability: 0.15
            )
        }
        let map = TerrainSupportMap(grid: grid)

        XCTAssertEqual(map.sample(localX: 4, localZ: 4).supportSolution, .flatFoundation)
        XCTAssertEqual(map.sample(localX: 20, localZ: 4).supportSolution, .steppedFoundation)
        XCTAssertEqual(map.sample(localX: 40, localZ: 4).supportSolution, .stilts)
        XCTAssertEqual(map.sample(localX: 48, localZ: 48).slopeClass, .unbuildable)
        XCTAssertGreaterThan(map.buildableRatio, 0.30)
        XCTAssertGreaterThan(map.waterAccessScore, 0.20)
    }

    func testSiteSelectorPrefersBuildablePocketOnHostileTerrain() {
        let seed = WorldSeed(22_002)
        let ruleset = ruleset(seed: seed, dna: settlementDNA(seed: 2))
        let grid = sampleGrid { localX, localZ in
            let inPocket = (26...38).contains(localX) && (26...38).contains(localZ)

            if inPocket {
                return SampleShape(slope: 0.05, roughness: 0.08, moisture: 0.72, walkability: 0.96)
            }

            return SampleShape(
                height: 1.2,
                slope: 0.74,
                roughness: 0.86,
                moisture: 0.20,
                featureMasks: TerrainFeatureMasks(cliff: 0.7),
                walkability: 0.10
            )
        }
        let map = TerrainSupportMap(grid: grid)
        let recipe = SettlementRecipe.makeV1(
            worldSeed: seed,
            ruleset: ruleset,
            biomeType: .grassland
        )
        let site = SettlementSiteSelector(worldSeed: seed)
            .selectSite(supportMap: map, recipe: recipe, ruleset: ruleset)

        XCTAssertGreaterThan(site.score, 0.50)
        XCTAssertTrue((22...42).contains(Int(site.localCenterX)))
        XCTAssertTrue((22...42).contains(Int(site.localCenterZ)))
    }

    func testFootprintsStayInsideChunkAndUseTerrainAdaptiveFoundations() {
        let seed = WorldSeed(22_003)
        let ruleset = ruleset(seed: seed, dna: settlementDNA(seed: 3))
        let grid = sampleGrid { localX, localZ in
            let height = Float(localX) * 0.018 + Float(localZ) * 0.012
            return SampleShape(height: height, slope: 0.22, roughness: 0.24, moisture: 0.50, walkability: 0.82)
        }
        let plan = SettlementSystem(worldSeed: seed).plan(
            for: .origin,
            terrainSampleGrid: grid,
            ruleset: ruleset
        )

        XCTAssertTrue(plan.validationReport.isValid, plan.validationReport.issues.joined(separator: ", "))
        XCTAssertTrue(plan.buildings.contains { $0.footprint.supportSolution != .flatFoundation })

        for building in plan.buildings {
            XCTAssertEqual(building.footprint.vertices.count, 4)
            XCTAssertGreaterThan(building.footprint.foundationAdjustments.count, 0)
            XCTAssertLessThanOrEqual(building.footprint.foundationMaxOffset, 2.3)

            for vertex in building.footprint.vertices {
                XCTAssertGreaterThanOrEqual(vertex.localX, 0)
                XCTAssertLessThanOrEqual(vertex.localX, Float(ChunkHeightmap.resolution - 1))
                XCTAssertGreaterThanOrEqual(vertex.localZ, 0)
                XCTAssertLessThanOrEqual(vertex.localZ, Float(ChunkHeightmap.resolution - 1))
            }
        }
    }

    func testMassingProducesRenderableInstancesAndBiomeMaterials() {
        let seed = WorldSeed(22_004)
        let ruleset = ruleset(seed: seed, dna: tradeDNA(seed: 4))
        let grid = sampleGrid(
            biome: .coast,
            slope: 0.10,
            roughness: 0.12,
            moisture: 0.78,
            waterDepth: 0.04,
            featureMasks: TerrainFeatureMasks(shore: 0.8),
            walkability: 0.88
        )
        let plan = SettlementSystem(worldSeed: seed).plan(
            for: .origin,
            terrainSampleGrid: grid,
            ruleset: ruleset
        )

        XCTAssertTrue(plan.renderInstances.allSatisfy(\.isVisible))
        XCTAssertTrue(plan.renderInstances.allSatisfy { !$0.geometry.parts.isEmpty })
        XCTAssertTrue(plan.renderInstances.allSatisfy { $0.primaryMaterial.identifier.contains("coast") })
        XCTAssertTrue(plan.renderInstances.allSatisfy { !$0.prototypeKey.isEmpty })
        XCTAssertEqual(Set(plan.renderInstances.map(\.id)).count, plan.renderInstances.count)
    }

    func testRPGRulesetInfluencesSettlementRecipeType() {
        let seed = WorldSeed(22_005)
        let tradeRules = ruleset(seed: seed, dna: tradeDNA(seed: 5))
        let rebuildRules = ruleset(seed: seed, dna: settlementDNA(seed: 6))
        let tradeRecipe = SettlementRecipe.makeV1(
            worldSeed: seed,
            ruleset: tradeRules,
            biomeType: .coast
        )
        let rebuildRecipe = SettlementRecipe.makeV1(
            worldSeed: seed,
            ruleset: rebuildRules,
            biomeType: .grassland
        )

        XCTAssertEqual(tradeRecipe.type, .tradePost)
        XCTAssertTrue([SettlementType.hamlet, .frontierOutpost].contains(rebuildRecipe.type))
        XCTAssertNotEqual(tradeRecipe.type, rebuildRecipe.type)
        XCTAssertTrue(tradeRecipe.tags.contains(.trade))
        XCTAssertTrue(rebuildRecipe.tags.contains(.settlement))
    }

    func testSettlementSubdomainVersionsChangeRelevantStableIDs() {
        let seed = WorldSeed(22_006)
        let ruleset = ruleset(seed: seed, dna: settlementDNA(seed: 7))
        let grid = sampleGrid(biome: .temperateForest, slope: 0.09, roughness: 0.12, moisture: 0.62, walkability: 0.92)
        let base = SettlementSystem(worldSeed: seed).plan(for: .origin, terrainSampleGrid: grid, ruleset: ruleset)
        let massingV2 = SettlementSystem(
            worldSeed: seed,
            generatorVersions: .current.setting(GeneratorVersion(major: 2), for: .buildingMassing)
        ).plan(for: .origin, terrainSampleGrid: grid, ruleset: ruleset)
        let siteV2 = SettlementSystem(
            worldSeed: seed,
            generatorVersions: .current.setting(GeneratorVersion(major: 2), for: .settlementSites)
        ).plan(for: .origin, terrainSampleGrid: grid, ruleset: ruleset)

        XCTAssertEqual(base.buildings.map(\.intent.id), massingV2.buildings.map(\.intent.id))
        XCTAssertEqual(base.buildings.map(\.footprint.id), massingV2.buildings.map(\.footprint.id))
        XCTAssertNotEqual(base.renderInstances.map(\.id), massingV2.renderInstances.map(\.id))
        XCTAssertNotEqual(base.site.id, siteV2.site.id)
    }

    func testReferenceSeedsProduceValidSettlementPlans() {
        for seed in Self.referenceSeeds {
            let dna = WorldRPGDNA.make(worldSeed: seed)
            let ruleset = WorldRuleset.make(worldSeed: seed, dna: dna)
            let grid = sampleGrid(
                biome: BiomeType.allCases[Int(seed.value % UInt64(BiomeType.allCases.count))],
                slope: 0.12,
                roughness: 0.18,
                moisture: 0.58,
                walkability: 0.90
            )
            let plan = SettlementSystem(worldSeed: seed).plan(
                for: .origin,
                terrainSampleGrid: grid,
                ruleset: ruleset
            )

            XCTAssertTrue(plan.validationReport.isValid, "Seed \(seed.value): \(plan.validationReport.issues)")
            XCTAssertGreaterThanOrEqual(plan.buildings.count, 2)
            XCTAssertEqual(plan.paths.count, max(plan.buildings.count - 1, 0))
            XCTAssertFalse(plan.debugSummary.isEmpty)
        }
    }

    private func ruleset(seed: WorldSeed, dna: WorldRPGDNA) -> WorldRuleset {
        WorldRuleset.make(worldSeed: seed, dna: dna)
    }

    private func settlementDNA(seed: UInt64) -> WorldRPGDNA {
        WorldRPGDNA(
            seed: seed,
            historySeed: seed + 1,
            factionSeed: seed + 2,
            questSeed: seed + 3,
            directorSeed: seed + 4,
            archetype: .settlementRebuild,
            era: .feudal,
            techLevel: .feudalCraft,
            magic: .none,
            threat: .wildlife,
            enemyPresence: .rare,
            mainObjective: .foundSettlement,
            progression: .crafting,
            tone: .pastoral,
            factionDensity: 0.62,
            questDensity: 0.55,
            violenceLevel: 0.24,
            wonderLevel: 0.30,
            ecologyPressure: 0.40,
            economyImportance: 0.46,
            worldTags: [.settlement, .crafting, .factions]
        )
    }

    private func tradeDNA(seed: UInt64) -> WorldRPGDNA {
        WorldRPGDNA(
            seed: seed,
            historySeed: seed + 10,
            factionSeed: seed + 11,
            questSeed: seed + 12,
            directorSeed: seed + 13,
            archetype: .craftGuild,
            era: .renaissance,
            techLevel: .clockwork,
            magic: .none,
            threat: .bandits,
            enemyPresence: .rare,
            mainObjective: .openTradeRoute,
            progression: .factionReputation,
            tone: .grounded,
            factionDensity: 0.72,
            questDensity: 0.60,
            violenceLevel: 0.32,
            wonderLevel: 0.24,
            ecologyPressure: 0.30,
            economyImportance: 0.90,
            worldTags: [.settlement, .trade, .crafting, .factions]
        )
    }

    private func sampleGrid(
        coordinate: ChunkCoordinate = .origin,
        biome: BiomeType,
        slope: Float,
        roughness: Float,
        moisture: Float,
        waterDepth: Float = 0,
        featureMasks: TerrainFeatureMasks = .zero,
        walkability: Float
    ) -> TerrainSampleGrid {
        sampleGrid(coordinate: coordinate) { _, _ in
            SampleShape(
                slope: slope,
                roughness: roughness,
                moisture: moisture,
                waterDepth: waterDepth,
                biome: biome,
                featureMasks: featureMasks,
                walkability: walkability
            )
        }
    }

    private func sampleGrid(
        coordinate: ChunkCoordinate = .origin,
        shape: (_ localX: Int, _ localZ: Int) -> SampleShape
    ) -> TerrainSampleGrid {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                let shape = shape(localX, localZ)
                samples.append(TerrainSample(
                    localX: localX,
                    localZ: localZ,
                    worldX: coordinate.x * ChunkHeightmap.gridStride + localX,
                    worldZ: coordinate.z * ChunkHeightmap.gridStride + localZ,
                    height: shape.height,
                    slope: shape.slope,
                    roughness: shape.roughness,
                    moisture: shape.moisture,
                    temperature: shape.temperature,
                    materialWeights: MaterialWeights(primaryBiome: Biome.definition(for: shape.biome)),
                    waterDepth: shape.waterDepth,
                    featureMasks: shape.featureMasks,
                    walkability: shape.walkability,
                    climbability: shape.climbability
                ))
            }
        }

        return TerrainSampleGrid(seed: WorldSeed(22_000), coordinate: coordinate, samples: samples)
    }

    private struct SampleShape {
        let height: Float
        let slope: Float
        let roughness: Float
        let moisture: Float
        let temperature: Float
        let waterDepth: Float
        let biome: BiomeType
        let featureMasks: TerrainFeatureMasks
        let walkability: Float
        let climbability: Float

        init(
            height: Float = 0,
            slope: Float,
            roughness: Float = 0.18,
            moisture: Float = 0.55,
            temperature: Float = 0.55,
            waterDepth: Float = 0,
            biome: BiomeType = .grassland,
            featureMasks: TerrainFeatureMasks = .zero,
            walkability: Float,
            climbability: Float = 0
        ) {
            self.height = height
            self.slope = slope
            self.roughness = roughness
            self.moisture = moisture
            self.temperature = temperature
            self.waterDepth = waterDepth
            self.biome = biome
            self.featureMasks = featureMasks
            self.walkability = walkability
            self.climbability = climbability
        }
    }

    private static let referenceSeeds: [WorldSeed] = [
        22_101, 22_202, 22_303, 22_404, 22_505,
        22_606, 22_707, 22_808,
    ]
}
