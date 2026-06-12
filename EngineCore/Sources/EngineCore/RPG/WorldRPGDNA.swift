public enum RPGEra: String, CaseIterable, Codable, Sendable {
    case prehistory
    case bronzeAge
    case feudal
    case renaissance
    case industrial
    case contemporaryStrange
    case postApocalypse
    case nearFuture
    case farFuture
    case fracturedAges
}

public enum RPGTechLevel: String, CaseIterable, Codable, Sendable {
    case naturalTools
    case primitiveMetal
    case feudalCraft
    case clockwork
    case industrial
    case electric
    case digital
    case cybernetic
    case transhuman
    case anomalousRelics
}

public enum RPGMagicProfile: String, CaseIterable, Codable, Sendable {
    case none
    case superstition
    case rareCostly
    case ecological
    case divine
    case memory
    case technomagic
    case unstableGeographic
}

public enum RPGThreatModel: String, CaseIterable, Codable, Sendable {
    case none
    case wildlife
    case bandits
    case mythicMonsters
    case contamination
    case famine
    case climateCollapse
    case factionWar
    case rogueMachines
    case secretCult
    case socialCollapse
    case timeLoop
    case cosmicUnknown
}

public enum RPGProgressionModel: String, CaseIterable, Codable, Sendable {
    case survival
    case exploration
    case mastery
    case knowledge
    case cartography
    case crafting
    case factionReputation
    case relationship
    case ritual
    case artifact
    case ecology
    case legacy
}

public enum RPGToneProfile: String, CaseIterable, Codable, Sendable {
    case grounded
    case pastoral
    case heroic
    case harsh
    case mysterious
    case surreal
}

public enum RPGEnemyPresence: String, CaseIterable, Codable, Sendable {
    case none
    case hazardsOnly
    case rare
    case common
    case systemic
}

public struct WorldRPGDNA: Hashable, Codable, Sendable {
    public let seed: UInt64
    public let historySeed: UInt64
    public let factionSeed: UInt64
    public let questSeed: UInt64
    public let directorSeed: UInt64
    public let archetype: RPGArchetype
    public let era: RPGEra
    public let techLevel: RPGTechLevel
    public let magic: RPGMagicProfile
    public let threat: RPGThreatModel
    public let enemyPresence: RPGEnemyPresence
    public let mainObjective: WorldObjectiveKind
    public let progression: RPGProgressionModel
    public let tone: RPGToneProfile
    public let factionDensity: Float
    public let questDensity: Float
    public let violenceLevel: Float
    public let wonderLevel: Float
    public let ecologyPressure: Float
    public let economyImportance: Float
    public let worldTags: [GameplayTag]

    public init(
        seed: UInt64,
        historySeed: UInt64,
        factionSeed: UInt64,
        questSeed: UInt64,
        directorSeed: UInt64,
        archetype: RPGArchetype,
        era: RPGEra,
        techLevel: RPGTechLevel,
        magic: RPGMagicProfile,
        threat: RPGThreatModel,
        enemyPresence: RPGEnemyPresence,
        mainObjective: WorldObjectiveKind,
        progression: RPGProgressionModel,
        tone: RPGToneProfile,
        factionDensity: Float,
        questDensity: Float,
        violenceLevel: Float,
        wonderLevel: Float,
        ecologyPressure: Float,
        economyImportance: Float,
        worldTags: [GameplayTag]
    ) {
        self.seed = seed
        self.historySeed = historySeed
        self.factionSeed = factionSeed
        self.questSeed = questSeed
        self.directorSeed = directorSeed
        self.archetype = archetype
        self.era = era
        self.techLevel = techLevel
        self.magic = magic
        self.threat = threat
        self.enemyPresence = enemyPresence
        self.mainObjective = mainObjective
        self.progression = progression
        self.tone = tone
        self.factionDensity = Self.clamped01(factionDensity)
        self.questDensity = Self.clamped01(questDensity)
        self.violenceLevel = Self.clamped01(violenceLevel)
        self.wonderLevel = Self.clamped01(wonderLevel)
        self.ecologyPressure = Self.clamped01(ecologyPressure)
        self.economyImportance = Self.clamped01(economyImportance)
        self.worldTags = worldTags.uniquedStable()
    }

    public static func make(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldRPGDNA {
        let seedValue = StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.rpgDNA)
            builder.combine(generatorVersions.version(for: .rpgDNA))
        }.value
        var rng = StableRNG(seedValue: seedValue)
        let archetype = RPGArchetype.allCases.stableElement(using: &rng)
        let era = era(for: archetype, rng: &rng)
        let techLevel = techLevel(for: era, archetype: archetype, rng: &rng)
        let magic = magic(for: archetype, techLevel: techLevel, rng: &rng)
        let threat = threat(for: archetype, magic: magic, rng: &rng)
        let objective = archetype.preferredObjectives.stableElement(using: &rng)
        let progression = archetype.preferredProgression.stableElement(using: &rng)
        let violence = violenceLevel(for: archetype, threat: threat, rng: &rng)
        let enemies = enemyPresence(for: threat, violenceLevel: violence)
        let wonder = magic == .none ? rng.nextFloat(in: 0.08...0.42) : rng.nextFloat(in: 0.38...0.90)
        let ecology = ecologyPressure(for: archetype, threat: threat, rng: &rng)
        let economy = economyImportance(for: archetype, rng: &rng)
        let tags = tags(
            archetype: archetype,
            techLevel: techLevel,
            magic: magic,
            threat: threat,
            enemyPresence: enemies,
            objective: objective,
            progression: progression,
            ecologyPressure: ecology,
            economyImportance: economy
        )

        return WorldRPGDNA(
            seed: seedValue,
            historySeed: rng.next(),
            factionSeed: rng.next(),
            questSeed: rng.next(),
            directorSeed: rng.next(),
            archetype: archetype,
            era: era,
            techLevel: techLevel,
            magic: magic,
            threat: threat,
            enemyPresence: enemies,
            mainObjective: objective,
            progression: progression,
            tone: RPGToneProfile.allCases.stableElement(using: &rng),
            factionDensity: factionDensity(for: archetype, rng: &rng),
            questDensity: rng.nextFloat(in: 0.35...0.88),
            violenceLevel: violence,
            wonderLevel: wonder,
            ecologyPressure: ecology,
            economyImportance: economy,
            worldTags: tags
        )
    }

    public var debugSummary: String {
        let tags = worldTags.map(\.rawValue).joined(separator: ", ")

        return [
            "RPG World DNA",
            "archetype: \(archetype.displayName)",
            "era/tech: \(era.rawValue) / \(techLevel.rawValue)",
            "magic/threat/enemies: \(magic.rawValue) / \(threat.rawValue) / \(enemyPresence.rawValue)",
            "objective: \(mainObjective.title)",
            "progression: \(progression.rawValue)",
            "tone: \(tone.rawValue)",
            "factions/quests: \(percent(factionDensity)) / \(percent(questDensity))",
            "tags: \(tags)",
        ].joined(separator: "\n")
    }

    private static func era(for archetype: RPGArchetype, rng: inout StableRNG) -> RPGEra {
        switch archetype {
        case .survivalFrontier:
            return [.prehistory, .bronzeAge, .feudal, .postApocalypse].stableElement(using: &rng)
        case .contemplativeExploration:
            return [.prehistory, .renaissance, .contemporaryStrange, .farFuture].stableElement(using: &rng)
        case .politicalIntrigue:
            return [.bronzeAge, .feudal, .renaissance, .industrial].stableElement(using: &rng)
        case .craftGuild:
            return [.feudal, .renaissance, .industrial, .nearFuture].stableElement(using: &rng)
        case .mythicPilgrimage:
            return [.bronzeAge, .feudal, .fracturedAges].stableElement(using: &rng)
        case .ecologicalRestoration:
            return [.prehistory, .postApocalypse, .nearFuture, .farFuture].stableElement(using: &rng)
        case .archaeologicalMystery:
            return [.bronzeAge, .renaissance, .postApocalypse, .farFuture].stableElement(using: &rng)
        case .settlementRebuild:
            return [.feudal, .industrial, .postApocalypse, .nearFuture].stableElement(using: &rng)
        case .postCollapseSurvival:
            return [.postApocalypse, .nearFuture, .fracturedAges].stableElement(using: &rng)
        case .cosmicAnomaly:
            return [.contemporaryStrange, .farFuture, .fracturedAges].stableElement(using: &rng)
        }
    }

    private static func techLevel(
        for era: RPGEra,
        archetype: RPGArchetype,
        rng: inout StableRNG
    ) -> RPGTechLevel {
        if archetype == .cosmicAnomaly && rng.nextBool(probability: 0.6) {
            return .anomalousRelics
        }

        switch era {
        case .prehistory:
            return [.naturalTools, .primitiveMetal].stableElement(using: &rng)
        case .bronzeAge:
            return [.primitiveMetal, .feudalCraft].stableElement(using: &rng)
        case .feudal:
            return [.feudalCraft, .clockwork].stableElement(using: &rng)
        case .renaissance:
            return [.clockwork, .industrial].stableElement(using: &rng)
        case .industrial:
            return [.industrial, .electric].stableElement(using: &rng)
        case .contemporaryStrange:
            return [.electric, .digital, .anomalousRelics].stableElement(using: &rng)
        case .postApocalypse:
            return [.naturalTools, .primitiveMetal, .industrial, .anomalousRelics].stableElement(using: &rng)
        case .nearFuture:
            return [.digital, .cybernetic].stableElement(using: &rng)
        case .farFuture:
            return [.cybernetic, .transhuman, .anomalousRelics].stableElement(using: &rng)
        case .fracturedAges:
            return RPGTechLevel.allCases.stableElement(using: &rng)
        }
    }

    private static func magic(
        for archetype: RPGArchetype,
        techLevel: RPGTechLevel,
        rng: inout StableRNG
    ) -> RPGMagicProfile {
        switch archetype {
        case .contemplativeExploration, .craftGuild, .settlementRebuild:
            return [.none, .superstition, .rareCostly].stableElement(using: &rng)
        case .mythicPilgrimage:
            return [.rareCostly, .ecological, .divine, .memory].stableElement(using: &rng)
        case .ecologicalRestoration:
            return [.none, .ecological, .unstableGeographic].stableElement(using: &rng)
        case .cosmicAnomaly:
            return [.memory, .technomagic, .unstableGeographic].stableElement(using: &rng)
        default:
            return techLevel == .anomalousRelics
                ? [.none, .technomagic, .memory].stableElement(using: &rng)
                : RPGMagicProfile.allCases.stableElement(using: &rng)
        }
    }

    private static func threat(
        for archetype: RPGArchetype,
        magic: RPGMagicProfile,
        rng: inout StableRNG
    ) -> RPGThreatModel {
        switch archetype {
        case .contemplativeExploration:
            return [.none, .wildlife, .climateCollapse].stableElement(using: &rng)
        case .politicalIntrigue:
            return [.factionWar, .secretCult, .socialCollapse].stableElement(using: &rng)
        case .craftGuild:
            return [.none, .bandits, .rogueMachines].stableElement(using: &rng)
        case .mythicPilgrimage:
            return magic == .divine ? .cosmicUnknown : [.mythicMonsters, .secretCult, .timeLoop].stableElement(using: &rng)
        case .ecologicalRestoration:
            return [.climateCollapse, .famine, .contamination].stableElement(using: &rng)
        case .archaeologicalMystery:
            return [.secretCult, .rogueMachines, .timeLoop, .cosmicUnknown].stableElement(using: &rng)
        case .postCollapseSurvival:
            return [.famine, .contamination, .rogueMachines, .socialCollapse].stableElement(using: &rng)
        case .cosmicAnomaly:
            return [.timeLoop, .cosmicUnknown].stableElement(using: &rng)
        default:
            return RPGThreatModel.allCases.stableElement(using: &rng)
        }
    }

    private static func violenceLevel(
        for archetype: RPGArchetype,
        threat: RPGThreatModel,
        rng: inout StableRNG
    ) -> Float {
        if archetype == .contemplativeExploration || threat == .none {
            return rng.nextFloat(in: 0.0...0.22)
        }

        switch threat {
        case .factionWar, .mythicMonsters, .rogueMachines:
            return rng.nextFloat(in: 0.55...0.92)
        case .bandits, .wildlife, .secretCult, .socialCollapse:
            return rng.nextFloat(in: 0.30...0.68)
        default:
            return rng.nextFloat(in: 0.12...0.55)
        }
    }

    private static func enemyPresence(
        for threat: RPGThreatModel,
        violenceLevel: Float
    ) -> RPGEnemyPresence {
        if threat == .none {
            return .none
        }

        if violenceLevel < 0.20 {
            return .hazardsOnly
        }

        if violenceLevel < 0.42 {
            return .rare
        }

        if violenceLevel < 0.70 {
            return .common
        }

        return .systemic
    }

    private static func ecologyPressure(
        for archetype: RPGArchetype,
        threat: RPGThreatModel,
        rng: inout StableRNG
    ) -> Float {
        if archetype == .ecologicalRestoration || [.climateCollapse, .famine, .contamination].contains(threat) {
            return rng.nextFloat(in: 0.62...0.95)
        }

        return rng.nextFloat(in: 0.10...0.68)
    }

    private static func economyImportance(
        for archetype: RPGArchetype,
        rng: inout StableRNG
    ) -> Float {
        switch archetype {
        case .politicalIntrigue, .craftGuild, .settlementRebuild:
            return rng.nextFloat(in: 0.58...0.92)
        case .contemplativeExploration, .cosmicAnomaly:
            return rng.nextFloat(in: 0.08...0.38)
        default:
            return rng.nextFloat(in: 0.24...0.72)
        }
    }

    private static func factionDensity(for archetype: RPGArchetype, rng: inout StableRNG) -> Float {
        switch archetype {
        case .politicalIntrigue:
            return rng.nextFloat(in: 0.72...0.95)
        case .contemplativeExploration:
            return rng.nextFloat(in: 0.12...0.36)
        default:
            return rng.nextFloat(in: 0.35...0.82)
        }
    }

    private static func tags(
        archetype: RPGArchetype,
        techLevel: RPGTechLevel,
        magic: RPGMagicProfile,
        threat: RPGThreatModel,
        enemyPresence: RPGEnemyPresence,
        objective: WorldObjectiveKind,
        progression: RPGProgressionModel,
        ecologyPressure: Float,
        economyImportance: Float
    ) -> [GameplayTag] {
        var tags = archetype.defaultTags + objective.defaultTags

        if techLevel != .naturalTools && techLevel != .primitiveMetal {
            tags.append(.technology)
        }

        if magic != .none && magic != .superstition {
            tags.append(.magic)
        }

        if threat != .none {
            tags.append(.threat)
        }

        if enemyPresence == .none || enemyPresence == .hazardsOnly {
            tags.append(.lowThreat)
        }

        if enemyPresence == .systemic {
            tags.append(.highThreat)
        }

        if progression == .factionReputation {
            tags.append(.factions)
        }

        if ecologyPressure > 0.55 {
            tags.append(.ecology)
        }

        if economyImportance > 0.55 {
            tags.append(.trade)
        }

        return tags.uniquedStable()
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value.isFinite ? value : 0, 0), 1)
    }

    private func percent(_ value: Float) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }
}

private extension Array {
    func stableElement(using rng: inout StableRNG) -> Element {
        self[rng.nextInt(upperBound: count)]
    }
}
