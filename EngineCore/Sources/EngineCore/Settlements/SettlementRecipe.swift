public enum SettlementType: String, CaseIterable, Codable, Sendable {
    case hamlet
    case camp
    case tradePost
    case shrineCluster
    case frontierOutpost
    case farmstead
    case ruinCluster
}

public enum SettlementPathKind: String, Codable, Sendable {
    case footpath
    case boardwalk
    case switchback
    case stonePath
}

public struct SettlementRecipe: Hashable, Codable, Sendable {
    public let id: String
    public let type: SettlementType
    public let displayName: String
    public let desiredBuildingCount: Int
    public let radius: Float
    public let maxSlope: Float
    public let waterNeed: Float
    public let tradeNeed: Float
    public let defenseNeed: Float
    public let pathKind: SettlementPathKind
    public let allowedSupportSolutions: [TerrainSupportSolution]
    public let buildingDistribution: [WeightedStructureRecipe]
    public let tags: [GameplayTag]

    public init(
        id: String,
        type: SettlementType,
        displayName: String,
        desiredBuildingCount: Int,
        radius: Float,
        maxSlope: Float,
        waterNeed: Float,
        tradeNeed: Float,
        defenseNeed: Float,
        pathKind: SettlementPathKind,
        allowedSupportSolutions: [TerrainSupportSolution],
        buildingDistribution: [WeightedStructureRecipe],
        tags: [GameplayTag]
    ) {
        precondition(!id.isEmpty, "SettlementRecipe id cannot be empty.")
        precondition(!displayName.isEmpty, "SettlementRecipe displayName cannot be empty.")
        precondition(desiredBuildingCount > 0, "SettlementRecipe needs at least one building.")
        precondition(radius > 0, "SettlementRecipe radius must be positive.")
        precondition(maxSlope > 0, "SettlementRecipe maxSlope must be positive.")
        precondition(!allowedSupportSolutions.isEmpty, "SettlementRecipe needs support solutions.")
        precondition(!buildingDistribution.isEmpty, "SettlementRecipe needs building distribution.")

        self.id = id
        self.type = type
        self.displayName = displayName
        self.desiredBuildingCount = desiredBuildingCount
        self.radius = radius
        self.maxSlope = maxSlope
        self.waterNeed = Self.clamped01(waterNeed)
        self.tradeNeed = Self.clamped01(tradeNeed)
        self.defenseNeed = Self.clamped01(defenseNeed)
        self.pathKind = pathKind
        self.allowedSupportSolutions = allowedSupportSolutions
        self.buildingDistribution = buildingDistribution
        self.tags = tags.uniquedStable()
    }

    public static func makeV1(
        worldSeed: WorldSeed,
        ruleset: WorldRuleset,
        biomeType: BiomeType,
        generatorVersions: GeneratorVersionTable = .current
    ) -> SettlementRecipe {
        var rng = StableRNG(seedValue: StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.settlementRecipes)
            builder.combine(generatorVersions.version(for: .settlementRecipes))
            builder.combine(ruleset.dna.seed)
            builder.combine(biomeType.rawValue)
        }.value)
        let type = settlementType(ruleset: ruleset, biomeType: biomeType, rng: &rng)
        let count = buildingCount(type: type, dna: ruleset.dna, rng: &rng)
        let pathKind = pathKind(type: type, biomeType: biomeType)
        let support = allowedSupportSolutions(type: type, biomeType: biomeType)
        let distribution = buildingDistribution(type: type, ruleset: ruleset)

        return SettlementRecipe(
            id: "settlement.\(type.rawValue).v1",
            type: type,
            displayName: displayName(for: type),
            desiredBuildingCount: count,
            radius: radius(type: type, count: count),
            maxSlope: maxSlope(type: type, biomeType: biomeType),
            waterNeed: waterNeed(type: type, biomeType: biomeType),
            tradeNeed: ruleset.dna.economyImportance,
            defenseNeed: ruleset.dna.violenceLevel,
            pathKind: pathKind,
            allowedSupportSolutions: support,
            buildingDistribution: distribution,
            tags: tags(type: type, ruleset: ruleset)
        )
    }

    public func chooseStructureRecipe(using rng: inout StableRNG) -> StructureRecipe {
        let totalWeight = buildingDistribution.reduce(Float(0)) { $0 + $1.weight }
        var roll = rng.nextFloat(in: 0...max(totalWeight, 0.0001))

        for weighted in buildingDistribution {
            roll -= weighted.weight

            if roll <= 0 {
                return weighted.recipe
            }
        }

        return buildingDistribution.last?.recipe ?? StructureRecipe.v1Catalog[0]
    }

    private static func settlementType(
        ruleset: WorldRuleset,
        biomeType: BiomeType,
        rng: inout StableRNG
    ) -> SettlementType {
        if ruleset.dna.mainObjective == .foundSettlement || ruleset.dna.archetype == .settlementRebuild {
            return rng.nextBool(probability: 0.65) ? .hamlet : .frontierOutpost
        }

        if ruleset.dna.worldTags.contains(.ruins) || ruleset.dna.archetype == .archaeologicalMystery {
            return .ruinCluster
        }

        if ruleset.dna.economyImportance > 0.62 || biomeType == .coast || biomeType == .freshwater {
            return .tradePost
        }

        if ruleset.dna.wonderLevel > 0.62 || ruleset.dna.magic != .none {
            return .shrineCluster
        }

        if ruleset.dna.violenceLevel > 0.58 || ruleset.dna.enemyPresence == .systemic {
            return .frontierOutpost
        }

        if biomeType == .grassland || biomeType == .temperateForest {
            return rng.nextBool(probability: 0.55) ? .farmstead : .hamlet
        }

        return .camp
    }

    private static func buildingCount(
        type: SettlementType,
        dna: WorldRPGDNA,
        rng: inout StableRNG
    ) -> Int {
        let base: Int

        switch type {
        case .camp:
            base = 3
        case .farmstead, .ruinCluster:
            base = 4
        case .tradePost, .shrineCluster, .frontierOutpost:
            base = 5
        case .hamlet:
            base = 6
        }

        let densityBonus = Int(((dna.factionDensity + dna.economyImportance) * 2.5).rounded())
        let jitter = rng.nextInt(upperBound: 2)
        return min(max(base + densityBonus + jitter, 2), 10)
    }

    private static func radius(type: SettlementType, count: Int) -> Float {
        let base: Float

        switch type {
        case .camp:
            base = 11
        case .farmstead, .ruinCluster:
            base = 14
        case .tradePost, .shrineCluster, .frontierOutpost:
            base = 16
        case .hamlet:
            base = 18
        }

        return base + Float(count) * 0.55
    }

    private static func maxSlope(type: SettlementType, biomeType: BiomeType) -> Float {
        let base: Float

        switch type {
        case .camp:
            base = 0.34
        case .frontierOutpost, .shrineCluster, .ruinCluster:
            base = 0.42
        case .hamlet, .farmstead, .tradePost:
            base = 0.28
        }

        return biomeType == .mountain ? base + 0.08 : base
    }

    private static func waterNeed(type: SettlementType, biomeType: BiomeType) -> Float {
        switch type {
        case .tradePost:
            return biomeType == .coast || biomeType == .freshwater ? 0.95 : 0.72
        case .farmstead:
            return 0.82
        case .camp:
            return 0.42
        case .shrineCluster:
            return 0.35
        case .frontierOutpost, .ruinCluster:
            return 0.28
        case .hamlet:
            return 0.62
        }
    }

    private static func pathKind(type: SettlementType, biomeType: BiomeType) -> SettlementPathKind {
        if biomeType == .marsh || biomeType == .freshwater {
            return .boardwalk
        }

        if biomeType == .mountain || type == .shrineCluster || type == .frontierOutpost {
            return .switchback
        }

        if type == .ruinCluster {
            return .stonePath
        }

        return .footpath
    }

    private static func allowedSupportSolutions(
        type: SettlementType,
        biomeType: BiomeType
    ) -> [TerrainSupportSolution] {
        var support: [TerrainSupportSolution] = [.flatFoundation, .steppedFoundation]

        if biomeType == .marsh || biomeType == .coast || biomeType == .freshwater {
            support.append(.stilts)
        }

        if biomeType == .mountain || type == .frontierOutpost || type == .shrineCluster {
            support.append(contentsOf: [.retainingWalls, .rockAnchors])
        }

        if type == .ruinCluster {
            support.append(contentsOf: [.retainingWalls, .terrace])
        }

        return support.uniquedStable()
    }

    private static func buildingDistribution(
        type: SettlementType,
        ruleset: WorldRuleset
    ) -> [WeightedStructureRecipe] {
        let catalog = StructureRecipe.v1Catalog

        func recipe(_ function: BuildingFunction) -> StructureRecipe {
            catalog.first { $0.function == function } ?? catalog[0]
        }

        var distribution: [WeightedStructureRecipe] = [
            WeightedStructureRecipe(recipe: recipe(.dwelling), weight: 4.5),
            WeightedStructureRecipe(recipe: recipe(.storage), weight: 1.2),
        ]

        switch type {
        case .camp:
            distribution = [
                WeightedStructureRecipe(recipe: recipe(.dwelling), weight: 3.0),
                WeightedStructureRecipe(recipe: recipe(.storage), weight: 1.2),
            ]
        case .farmstead:
            distribution.append(WeightedStructureRecipe(recipe: recipe(.farm), weight: 2.4))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.workshop), weight: 0.8))
        case .tradePost:
            distribution.append(WeightedStructureRecipe(recipe: recipe(.market), weight: 2.7))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.workshop), weight: 1.4))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.hall), weight: 0.8))
        case .shrineCluster:
            distribution.append(WeightedStructureRecipe(recipe: recipe(.shrine), weight: 3.2))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.hall), weight: 0.9))
        case .frontierOutpost:
            distribution.append(WeightedStructureRecipe(recipe: recipe(.watchtower), weight: 2.2))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.workshop), weight: 1.0))
        case .ruinCluster:
            distribution.append(WeightedStructureRecipe(recipe: recipe(.shrine), weight: 1.0))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.watchtower), weight: 0.8))
        case .hamlet:
            distribution.append(WeightedStructureRecipe(recipe: recipe(.hall), weight: 1.0))
            distribution.append(WeightedStructureRecipe(recipe: recipe(.workshop), weight: ruleset.dna.economyImportance + 0.4))
        }

        return distribution
    }

    private static func displayName(for type: SettlementType) -> String {
        switch type {
        case .hamlet:
            return "Terrain hamlet"
        case .camp:
            return "Seasonal camp"
        case .tradePost:
            return "Trade post"
        case .shrineCluster:
            return "Shrine cluster"
        case .frontierOutpost:
            return "Frontier outpost"
        case .farmstead:
            return "Farmstead"
        case .ruinCluster:
            return "Ruin cluster"
        }
    }

    private static func tags(type: SettlementType, ruleset: WorldRuleset) -> [GameplayTag] {
        var tags: [GameplayTag] = [.settlement, .buildings, .pathNetwork, .terrainAdapted]

        if ruleset.dna.economyImportance > 0.45 || type == .tradePost {
            tags.append(.trade)
        }

        if ruleset.dna.violenceLevel > 0.45 || type == .frontierOutpost {
            tags.append(.threat)
        }

        if type == .shrineCluster {
            tags.append(.myth)
        }

        if type == .ruinCluster {
            tags.append(.ruins)
        }

        return tags.uniquedStable()
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct SettlementPathSegment: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: SettlementPathKind
    public let start: WorldPosition
    public let end: WorldPosition
    public let width: Float
    public let slopeCost: Float

    public init(
        id: StableID,
        kind: SettlementPathKind,
        start: WorldPosition,
        end: WorldPosition,
        width: Float,
        slopeCost: Float
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.width = max(width, 0.25)
        self.slopeCost = max(slopeCost, 0)
    }
}

public struct SettlementBuilding: Equatable, Codable, Sendable {
    public let intent: BuildingIntent
    public let footprint: BuildingFootprint
    public let massing: BuildingMassing

    public init(
        intent: BuildingIntent,
        footprint: BuildingFootprint,
        massing: BuildingMassing
    ) {
        self.intent = intent
        self.footprint = footprint
        self.massing = massing
    }
}

public struct SettlementValidationReport: Equatable, Codable, Sendable {
    public let isValid: Bool
    public let issues: [String]

    public init(issues: [String]) {
        self.issues = issues
        isValid = issues.isEmpty
    }
}

public struct SettlementPlan: Equatable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let site: SettlementSiteCandidate
    public let recipe: SettlementRecipe
    public let buildings: [SettlementBuilding]
    public let paths: [SettlementPathSegment]
    public let renderInstances: [StructureRenderInstance]

    public init(
        worldSeed: WorldSeed,
        coordinate: ChunkCoordinate,
        site: SettlementSiteCandidate,
        recipe: SettlementRecipe,
        buildings: [SettlementBuilding],
        paths: [SettlementPathSegment],
        renderInstances: [StructureRenderInstance]
    ) {
        self.worldSeed = worldSeed
        self.coordinate = coordinate
        self.site = site
        self.recipe = recipe
        self.buildings = buildings
        self.paths = paths
        self.renderInstances = renderInstances
    }

    public var validationReport: SettlementValidationReport {
        var issues: [String] = []

        if buildings.isEmpty {
            issues.append("Settlement has no buildings.")
        }

        if Set(buildings.map(\.intent.id)).count != buildings.count {
            issues.append("Building intent IDs are not unique.")
        }

        if renderInstances.count != buildings.count {
            issues.append("Render instances do not match building count.")
        }

        if buildings.contains(where: { $0.footprint.buildableScore < 0.25 }) {
            issues.append("At least one footprint is below the minimum buildable score.")
        }

        let maxLocal = Float(ChunkHeightmap.resolution - 1)
        for building in buildings {
            for vertex in building.footprint.vertices where vertex.localX < 0 ||
                vertex.localX > maxLocal ||
                vertex.localZ < 0 ||
                vertex.localZ > maxLocal {
                issues.append("A building footprint escapes its source chunk.")
                break
            }
        }

        return SettlementValidationReport(issues: issues)
    }

    public var debugSummary: String {
        let functions = buildings.map { $0.intent.function.rawValue }.joined(separator: ", ")
        return [
            "Settlement Plan",
            "type: \(recipe.displayName)",
            "site score: \(site.score)",
            "biome: \(site.biomeType.rawValue)",
            "buildings: \(buildings.count)",
            "paths: \(paths.count)",
            "functions: \(functions)",
        ].joined(separator: "\n")
    }
}

private extension Array where Element == TerrainSupportSolution {
    func uniquedStable() -> [TerrainSupportSolution] {
        var seen: Set<TerrainSupportSolution> = []
        var result: [TerrainSupportSolution] = []

        for item in self where seen.insert(item).inserted {
            result.append(item)
        }

        return result
    }
}
