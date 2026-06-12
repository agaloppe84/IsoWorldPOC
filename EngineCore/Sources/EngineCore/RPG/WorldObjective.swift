public enum WorldObjectiveKind: String, CaseIterable, Codable, Sendable {
    case defeatThreat
    case avoidViolence
    case repairArtifact
    case repairWorldSystem
    case mapWorld
    case saveBiome
    case restoreWater
    case wakeDivinity
    case foundSettlement
    case uniteFactions
    case surviveSeasons
    case masterCraft
    case buildImpossibleMachine
    case openTradeRoute
    case reachMythicPlace
    case recoverMemory
    case discoverWorldTruth
    case writeWorldName
    case chooseNextAge
    case preserveBalance
    case breakTimeLoop
    case escapeWorld

    public var title: String {
        switch self {
        case .defeatThreat:
            "Defeat the central threat"
        case .avoidViolence:
            "Resolve the world without killing"
        case .repairArtifact:
            "Repair the broken artifact"
        case .repairWorldSystem:
            "Repair the world system"
        case .mapWorld:
            "Map and name the world"
        case .saveBiome:
            "Save a failing biome"
        case .restoreWater:
            "Restore the water cycle"
        case .wakeDivinity:
            "Wake the dormant divinity"
        case .foundSettlement:
            "Found a lasting settlement"
        case .uniteFactions:
            "Unite the major factions"
        case .surviveSeasons:
            "Survive the harsh seasons"
        case .masterCraft:
            "Master a defining craft"
        case .buildImpossibleMachine:
            "Build the impossible machine"
        case .openTradeRoute:
            "Open a safe trade route"
        case .reachMythicPlace:
            "Reach the mythic place"
        case .recoverMemory:
            "Recover the lost memory"
        case .discoverWorldTruth:
            "Discover why the world exists"
        case .writeWorldName:
            "Write the true name of the world"
        case .chooseNextAge:
            "Choose the next age"
        case .preserveBalance:
            "Preserve the balance"
        case .breakTimeLoop:
            "Break the time loop"
        case .escapeWorld:
            "Escape the world"
        }
    }

    public var defaultTags: [GameplayTag] {
        switch self {
        case .defeatThreat:
            [.combat, .threat]
        case .avoidViolence:
            [.nonViolent, .social]
        case .repairArtifact, .repairWorldSystem, .buildImpossibleMachine:
            [.crafting, .technology, .knowledge]
        case .mapWorld, .reachMythicPlace:
            [.exploration, .knowledge]
        case .saveBiome, .restoreWater, .preserveBalance:
            [.ecology, .climate]
        case .wakeDivinity, .writeWorldName, .chooseNextAge:
            [.myth, .magic]
        case .foundSettlement:
            [.settlement, .crafting]
        case .uniteFactions, .openTradeRoute:
            [.factions, .social, .trade]
        case .surviveSeasons:
            [.survival, .climate]
        case .masterCraft:
            [.crafting, .knowledge]
        case .recoverMemory:
            [.memory, .mystery]
        case .discoverWorldTruth, .breakTimeLoop:
            [.mystery, .knowledge]
        case .escapeWorld:
            [.survival, .exploration]
        }
    }
}

public struct WorldObjective: Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: WorldObjectiveKind
    public let title: String
    public let summary: String
    public let tags: [GameplayTag]
    public let requiredProgress: Float
    public let milestoneCount: Int

    public init(
        id: StableID,
        kind: WorldObjectiveKind,
        title: String? = nil,
        summary: String,
        tags: [GameplayTag],
        requiredProgress: Float,
        milestoneCount: Int
    ) {
        self.id = id
        self.kind = kind
        self.title = title ?? kind.title
        self.summary = summary
        self.tags = tags.uniquedStable()
        self.requiredProgress = min(max(requiredProgress.isFinite ? requiredProgress : 1, 0.1), 1)
        self.milestoneCount = max(milestoneCount, 1)
    }

    public static func primary(
        worldSeed: WorldSeed,
        dna: WorldRPGDNA,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldObjective {
        let versionHash = StableHash.make { builder in
            builder.combine(generatorVersions.version(for: .rpgObjectives))
        }

        return WorldObjective(
            id: StableID.make(
                worldSeed: worldSeed,
                domain: .rpgObjectives,
                values: [versionHash.value, dna.seed, 0]
            ),
            kind: dna.mainObjective,
            summary: "Primary objective for a \(dna.archetype.displayName.lowercased()) world.",
            tags: (dna.mainObjective.defaultTags + dna.archetype.defaultTags).uniquedStable(),
            requiredProgress: 1,
            milestoneCount: 3 + Int(dna.questDensity * 3)
        )
    }
}
