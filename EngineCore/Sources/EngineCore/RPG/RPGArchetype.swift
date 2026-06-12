public enum RPGArchetype: String, CaseIterable, Codable, Sendable {
    case survivalFrontier
    case contemplativeExploration
    case politicalIntrigue
    case craftGuild
    case mythicPilgrimage
    case ecologicalRestoration
    case archaeologicalMystery
    case settlementRebuild
    case postCollapseSurvival
    case cosmicAnomaly

    public var displayName: String {
        switch self {
        case .survivalFrontier:
            "Survival frontier"
        case .contemplativeExploration:
            "Contemplative exploration"
        case .politicalIntrigue:
            "Political intrigue"
        case .craftGuild:
            "Craft guild"
        case .mythicPilgrimage:
            "Mythic pilgrimage"
        case .ecologicalRestoration:
            "Ecological restoration"
        case .archaeologicalMystery:
            "Archaeological mystery"
        case .settlementRebuild:
            "Settlement rebuild"
        case .postCollapseSurvival:
            "Post-collapse survival"
        case .cosmicAnomaly:
            "Cosmic anomaly"
        }
    }

    public var defaultTags: [GameplayTag] {
        switch self {
        case .survivalFrontier:
            [.survival, .exploration, .threat]
        case .contemplativeExploration:
            [.exploration, .knowledge, .nonViolent, .lowThreat]
        case .politicalIntrigue:
            [.factions, .social, .trade]
        case .craftGuild:
            [.crafting, .trade, .knowledge]
        case .mythicPilgrimage:
            [.myth, .exploration, .magic]
        case .ecologicalRestoration:
            [.ecology, .climate, .nonViolent]
        case .archaeologicalMystery:
            [.mystery, .ruins, .knowledge]
        case .settlementRebuild:
            [.settlement, .crafting, .factions]
        case .postCollapseSurvival:
            [.survival, .ruins, .highThreat]
        case .cosmicAnomaly:
            [.mystery, .myth, .technology]
        }
    }

    public var preferredObjectives: [WorldObjectiveKind] {
        switch self {
        case .survivalFrontier:
            [.surviveSeasons, .foundSettlement, .mapWorld]
        case .contemplativeExploration:
            [.mapWorld, .writeWorldName, .preserveBalance]
        case .politicalIntrigue:
            [.uniteFactions, .openTradeRoute, .chooseNextAge]
        case .craftGuild:
            [.masterCraft, .buildImpossibleMachine, .repairArtifact]
        case .mythicPilgrimage:
            [.reachMythicPlace, .wakeDivinity, .writeWorldName]
        case .ecologicalRestoration:
            [.restoreWater, .saveBiome, .preserveBalance]
        case .archaeologicalMystery:
            [.recoverMemory, .discoverWorldTruth, .repairArtifact]
        case .settlementRebuild:
            [.foundSettlement, .repairArtifact, .openTradeRoute]
        case .postCollapseSurvival:
            [.surviveSeasons, .repairWorldSystem, .escapeWorld]
        case .cosmicAnomaly:
            [.breakTimeLoop, .discoverWorldTruth, .chooseNextAge]
        }
    }

    public var preferredProgression: [RPGProgressionModel] {
        switch self {
        case .survivalFrontier:
            [.survival, .exploration, .crafting]
        case .contemplativeExploration:
            [.cartography, .knowledge, .relationship]
        case .politicalIntrigue:
            [.factionReputation, .relationship, .knowledge]
        case .craftGuild:
            [.crafting, .mastery, .knowledge]
        case .mythicPilgrimage:
            [.ritual, .knowledge, .legacy]
        case .ecologicalRestoration:
            [.ecology, .knowledge, .mastery]
        case .archaeologicalMystery:
            [.knowledge, .cartography, .artifact]
        case .settlementRebuild:
            [.crafting, .factionReputation, .survival]
        case .postCollapseSurvival:
            [.survival, .artifact, .crafting]
        case .cosmicAnomaly:
            [.knowledge, .artifact, .legacy]
        }
    }
}
