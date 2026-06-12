public enum RPGWorldSystem: String, CaseIterable, Codable, Sendable {
    case combat
    case exploration
    case crafting
    case factions
    case ecology
    case mystery
    case trade
    case settlement
    case magic
    case technology
}

public enum RPGViolencePolicy: String, Codable, Sendable {
    case forbidden
    case discouraged
    case optional
    case expected
}

public struct WorldRulesetValidationReport: Hashable, Codable, Sendable {
    public let isPlayable: Bool
    public let issues: [String]

    public init(issues: [String]) {
        self.issues = issues
        self.isPlayable = issues.isEmpty
    }
}

public struct WorldRuleset: Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let dna: WorldRPGDNA
    public let enabledSystems: [RPGWorldSystem]
    public let globalTags: [GameplayTag]
    public let violencePolicy: RPGViolencePolicy
    public let primaryObjective: WorldObjective
    public let factions: [FactionDefinition]
    public let questSeeds: [QuestSeed]

    public init(
        worldSeed: WorldSeed,
        dna: WorldRPGDNA,
        enabledSystems: [RPGWorldSystem],
        globalTags: [GameplayTag],
        violencePolicy: RPGViolencePolicy,
        primaryObjective: WorldObjective,
        factions: [FactionDefinition],
        questSeeds: [QuestSeed]
    ) {
        self.worldSeed = worldSeed
        self.dna = dna
        self.enabledSystems = enabledSystems.uniquedStable()
        self.globalTags = globalTags.uniquedStable()
        self.violencePolicy = violencePolicy
        self.primaryObjective = primaryObjective
        self.factions = factions
        self.questSeeds = questSeeds
    }

    public static func make(
        worldSeed: WorldSeed,
        dna: WorldRPGDNA,
        generatorVersions: GeneratorVersionTable = .current
    ) -> WorldRuleset {
        let objective = WorldObjective.primary(
            worldSeed: worldSeed,
            dna: dna,
            generatorVersions: generatorVersions
        )
        let factionCount = max(1, min(6, Int((dna.factionDensity * 5).rounded()) + 1))
        let factions = (0..<factionCount).map { index in
            FactionDefinition.makeV1(
                worldSeed: worldSeed,
                dna: dna,
                index: index,
                generatorVersions: generatorVersions
            )
        }
        let questCount = max(3, min(8, Int((dna.questDensity * 6).rounded()) + 2))
        let quests = (0..<questCount).map { index in
            QuestSeed.makeV1(
                worldSeed: worldSeed,
                dna: dna,
                objective: objective,
                factions: factions,
                index: index,
                generatorVersions: generatorVersions
            )
        }

        return WorldRuleset(
            worldSeed: worldSeed,
            dna: dna,
            enabledSystems: enabledSystems(for: dna),
            globalTags: (dna.worldTags + objective.tags).uniquedStable(),
            violencePolicy: violencePolicy(for: dna),
            primaryObjective: objective,
            factions: factions,
            questSeeds: quests
        )
    }

    public var validationReport: WorldRulesetValidationReport {
        var issues: [String] = []

        if primaryObjective.requiredProgress <= 0 {
            issues.append("Primary objective has no progress requirement.")
        }

        if questSeeds.isEmpty {
            issues.append("No quest seeds were generated.")
        }

        if Set(questSeeds.map(\.id)).count != questSeeds.count {
            issues.append("Quest seed IDs are not unique.")
        }

        if Set(factions.map(\.id)).count != factions.count {
            issues.append("Faction IDs are not unique.")
        }

        if dna.enemyPresence == .none && enabledSystems.contains(.combat) {
            issues.append("Combat system enabled in an enemy-free world.")
        }

        if dna.mainObjective == .uniteFactions && factions.count < 2 {
            issues.append("Faction unification needs at least two factions.")
        }

        return WorldRulesetValidationReport(issues: issues)
    }

    public var debugSummary: String {
        let systems = enabledSystems.map(\.rawValue).joined(separator: ", ")
        let factionNames = factions.map(\.name).joined(separator: ", ")
        let questTitles = questSeeds.map(\.title).joined(separator: " | ")

        return [
            dna.debugSummary,
            "ruleset systems: \(systems)",
            "violence policy: \(violencePolicy.rawValue)",
            "primary objective: \(primaryObjective.title)",
            "factions: \(factionNames)",
            "quest seeds: \(questTitles)",
        ].joined(separator: "\n")
    }

    private static func enabledSystems(for dna: WorldRPGDNA) -> [RPGWorldSystem] {
        var systems: [RPGWorldSystem] = [.exploration]

        if dna.enemyPresence != .none && dna.violenceLevel > 0.22 {
            systems.append(.combat)
        }

        if dna.worldTags.contains(.crafting) {
            systems.append(.crafting)
        }

        if dna.factionDensity > 0.25 {
            systems.append(.factions)
        }

        if dna.ecologyPressure > 0.35 {
            systems.append(.ecology)
        }

        if dna.worldTags.contains(.mystery) {
            systems.append(.mystery)
        }

        if dna.economyImportance > 0.42 {
            systems.append(.trade)
        }

        if dna.worldTags.contains(.settlement) {
            systems.append(.settlement)
        }

        if dna.worldTags.contains(.magic) {
            systems.append(.magic)
        }

        if dna.worldTags.contains(.technology) {
            systems.append(.technology)
        }

        return systems.uniquedStable()
    }

    private static func violencePolicy(for dna: WorldRPGDNA) -> RPGViolencePolicy {
        if dna.mainObjective == .avoidViolence || dna.violenceLevel < 0.12 {
            return .forbidden
        }

        if dna.violenceLevel < 0.35 {
            return .discouraged
        }

        if dna.violenceLevel < 0.68 {
            return .optional
        }

        return .expected
    }
}

private extension Array where Element == RPGWorldSystem {
    func uniquedStable() -> [RPGWorldSystem] {
        var seen: Set<RPGWorldSystem> = []
        var result: [RPGWorldSystem] = []

        for system in self where seen.insert(system).inserted {
            result.append(system)
        }

        return result
    }
}
