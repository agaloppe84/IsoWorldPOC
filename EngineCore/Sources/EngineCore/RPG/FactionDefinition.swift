public enum FactionRole: String, CaseIterable, Codable, Sendable {
    case clan
    case guild
    case order
    case commune
    case scholars
    case cult
    case machineCollective
    case nomads
    case settlementCouncil
    case ecologicalWardens
}

public enum FactionStance: String, CaseIterable, Codable, Sendable {
    case ally
    case neutral
    case rival
    case hostile
    case hidden
}

public struct FactionDefinition: Hashable, Codable, Sendable {
    public let id: StableID
    public let name: String
    public let role: FactionRole
    public let stance: FactionStance
    public let influence: Float
    public let homeBiome: BiomeType
    public let tags: [GameplayTag]

    public init(
        id: StableID,
        name: String,
        role: FactionRole,
        stance: FactionStance,
        influence: Float,
        homeBiome: BiomeType,
        tags: [GameplayTag]
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.stance = stance
        self.influence = min(max(influence.isFinite ? influence : 0, 0), 1)
        self.homeBiome = homeBiome
        self.tags = tags.uniquedStable()
    }

    public static func makeV1(
        worldSeed: WorldSeed,
        dna: WorldRPGDNA,
        index: Int,
        generatorVersions: GeneratorVersionTable = .current
    ) -> FactionDefinition {
        let versionHash = StableHash.make { builder in
            builder.combine(generatorVersions.version(for: .rpgFactions))
        }
        var rng = StableRNG(
            seed: worldSeed,
            domain: .rpgFactions,
            values: [
                versionHash.value,
                dna.factionSeed,
                UInt64(bitPattern: Int64(index)),
            ]
        )
        let role = roleCandidates(for: dna).stableElement(using: &rng)
        let stance = stanceCandidates(for: dna, index: index).stableElement(using: &rng)
        let biome = BiomeType.allCases.stableElement(using: &rng)
        let name = "\(prefixes.stableElement(using: &rng)) \(nouns(for: role).stableElement(using: &rng))"

        return FactionDefinition(
            id: StableID.make(
                worldSeed: worldSeed,
                domain: .rpgFactions,
                values: [
                    versionHash.value,
                    dna.factionSeed,
                    UInt64(bitPattern: Int64(index)),
                ]
            ),
            name: name,
            role: role,
            stance: stance,
            influence: rng.nextFloat(in: 0.25...0.90),
            homeBiome: biome,
            tags: tags(for: role, stance: stance, dna: dna)
        )
    }

    private static func roleCandidates(for dna: WorldRPGDNA) -> [FactionRole] {
        switch dna.archetype {
        case .politicalIntrigue:
            [.guild, .order, .settlementCouncil, .clan, .cult]
        case .craftGuild:
            [.guild, .scholars, .settlementCouncil]
        case .ecologicalRestoration:
            [.ecologicalWardens, .commune, .scholars, .nomads]
        case .cosmicAnomaly:
            [.scholars, .cult, .machineCollective]
        case .postCollapseSurvival:
            [.clan, .nomads, .machineCollective, .commune]
        default:
            FactionRole.allCases
        }
    }

    private static func stanceCandidates(
        for dna: WorldRPGDNA,
        index: Int
    ) -> [FactionStance] {
        if index == 0 {
            return [.ally, .neutral]
        }

        if dna.enemyPresence == .systemic || dna.threat == .factionWar {
            return [.rival, .hostile, .hidden, .neutral]
        }

        if dna.enemyPresence == .none {
            return [.ally, .neutral, .rival]
        }

        return [.neutral, .rival, .hidden]
    }

    private static func tags(
        for role: FactionRole,
        stance: FactionStance,
        dna: WorldRPGDNA
    ) -> [GameplayTag] {
        var tags: [GameplayTag] = [.factions]

        switch role {
        case .guild:
            tags.append(.trade)
            tags.append(.crafting)
        case .scholars:
            tags.append(.knowledge)
        case .cult:
            tags.append(.myth)
            tags.append(.mystery)
        case .machineCollective:
            tags.append(.technology)
        case .ecologicalWardens:
            tags.append(.ecology)
        case .commune, .settlementCouncil:
            tags.append(.settlement)
            tags.append(.social)
        case .clan, .nomads, .order:
            tags.append(.social)
        }

        if stance == .hostile {
            tags.append(.threat)
        }

        return (tags + dna.worldTags.filter { $0 == .magic || $0 == .technology }).uniquedStable()
    }

    private static let prefixes = [
        "Amber", "Ashen", "Bright", "Deep", "First", "Green", "Hidden", "Iron",
        "Last", "Salt", "Silent", "Solar", "Stone", "Verdant", "Wind",
    ]

    private static func nouns(for role: FactionRole) -> [String] {
        switch role {
        case .clan:
            ["Clan", "Kin", "Hearth"]
        case .guild:
            ["Guild", "League", "Compact"]
        case .order:
            ["Order", "Oath", "Banner"]
        case .commune:
            ["Commune", "Circle", "Assembly"]
        case .scholars:
            ["Archive", "College", "Index"]
        case .cult:
            ["Veil", "Choir", "Covenant"]
        case .machineCollective:
            ["Engine", "Array", "Foundry"]
        case .nomads:
            ["Caravan", "Trail", "Camp"]
        case .settlementCouncil:
            ["Council", "Charter", "Ward"]
        case .ecologicalWardens:
            ["Wardens", "Grove", "Keepers"]
        }
    }
}

private extension Array {
    func stableElement(using rng: inout StableRNG) -> Element {
        self[rng.nextInt(upperBound: count)]
    }
}
