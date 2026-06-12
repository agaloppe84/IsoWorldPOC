public enum QuestSeedKind: String, CaseIterable, Codable, Sendable {
    case main
    case faction
    case biome
    case crafting
    case exploration
    case restoration
    case mystery
}

public struct QuestSeed: Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: QuestSeedKind
    public let title: String
    public let objectiveKind: WorldObjectiveKind
    public let requiredTags: [GameplayTag]
    public let targetFactionID: StableID?
    public let targetBiome: BiomeType?
    public let stageCount: Int
    public let urgency: Float

    public init(
        id: StableID,
        kind: QuestSeedKind,
        title: String,
        objectiveKind: WorldObjectiveKind,
        requiredTags: [GameplayTag],
        targetFactionID: StableID?,
        targetBiome: BiomeType?,
        stageCount: Int,
        urgency: Float
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.objectiveKind = objectiveKind
        self.requiredTags = requiredTags.uniquedStable()
        self.targetFactionID = targetFactionID
        self.targetBiome = targetBiome
        self.stageCount = max(stageCount, 1)
        self.urgency = min(max(urgency.isFinite ? urgency : 0, 0), 1)
    }

    public static func makeV1(
        worldSeed: WorldSeed,
        dna: WorldRPGDNA,
        objective: WorldObjective,
        factions: [FactionDefinition],
        index: Int,
        generatorVersions: GeneratorVersionTable = .current
    ) -> QuestSeed {
        let versionHash = StableHash.make { builder in
            builder.combine(generatorVersions.version(for: .rpgQuests))
        }
        var rng = StableRNG(
            seed: worldSeed,
            domain: .rpgQuests,
            values: [
                versionHash.value,
                dna.questSeed,
                UInt64(bitPattern: Int64(index)),
            ]
        )
        let kind = questKind(for: dna, index: index, rng: &rng)
        let faction = factions.isEmpty ? nil : factions[rng.nextInt(upperBound: factions.count)]
        let biome = rng.nextBool(probability: 0.55) ? BiomeType.allCases.stableElement(using: &rng) : nil

        return QuestSeed(
            id: StableID.make(
                worldSeed: worldSeed,
                domain: .rpgQuests,
                values: [
                    versionHash.value,
                    dna.questSeed,
                    UInt64(bitPattern: Int64(index)),
                ]
            ),
            kind: kind,
            title: title(kind: kind, objective: objective.kind),
            objectiveKind: objective.kind,
            requiredTags: requiredTags(kind: kind, objective: objective, dna: dna),
            targetFactionID: faction?.id,
            targetBiome: biome,
            stageCount: 2 + rng.nextInt(upperBound: max(2, objective.milestoneCount + 1)),
            urgency: urgency(kind: kind, dna: dna, rng: &rng)
        )
    }

    private static func questKind(
        for dna: WorldRPGDNA,
        index: Int,
        rng: inout StableRNG
    ) -> QuestSeedKind {
        if index == 0 {
            return .main
        }

        if dna.worldTags.contains(.ecology) {
            return [.restoration, .biome, .exploration].stableElement(using: &rng)
        }

        if dna.worldTags.contains(.mystery) {
            return [.mystery, .exploration, .faction].stableElement(using: &rng)
        }

        if dna.worldTags.contains(.crafting) {
            return [.crafting, .faction, .exploration].stableElement(using: &rng)
        }

        return QuestSeedKind.allCases.stableElement(using: &rng)
    }

    private static func title(kind: QuestSeedKind, objective: WorldObjectiveKind) -> String {
        switch kind {
        case .main:
            return objective.title
        case .faction:
            return "Faction pressure"
        case .biome:
            return "Biome signal"
        case .crafting:
            return "Crafting requirement"
        case .exploration:
            return "Exploration lead"
        case .restoration:
            return "Restoration work"
        case .mystery:
            return "Hidden cause"
        }
    }

    private static func requiredTags(
        kind: QuestSeedKind,
        objective: WorldObjective,
        dna: WorldRPGDNA
    ) -> [GameplayTag] {
        let kindTags: [GameplayTag]

        switch kind {
        case .main:
            kindTags = objective.tags
        case .faction:
            kindTags = [.factions, .social]
        case .biome:
            kindTags = [.ecology, .exploration]
        case .crafting:
            kindTags = [.crafting, .knowledge]
        case .exploration:
            kindTags = [.exploration, .knowledge]
        case .restoration:
            kindTags = [.ecology, .climate]
        case .mystery:
            kindTags = [.mystery, .knowledge]
        }

        return (kindTags + dna.worldTags.prefix(3)).uniquedStable()
    }

    private static func urgency(
        kind: QuestSeedKind,
        dna: WorldRPGDNA,
        rng: inout StableRNG
    ) -> Float {
        let base: ClosedRange<Float> = kind == .main ? 0.55...0.95 : 0.18...0.72
        let pressure = max(dna.ecologyPressure, dna.violenceLevel) * 0.18
        return min(rng.nextFloat(in: base) + pressure, 1)
    }
}

private extension Array {
    func stableElement(using rng: inout StableRNG) -> Element {
        self[rng.nextInt(upperBound: count)]
    }
}
