public enum WorldStateFactKind: String, Codable, Sendable {
    case questActivated
    case objectiveProgress
    case factionReputation
    case discoveredFact
    case lawViolated
    case resourceUnlocked
    case worldFlag
}

public struct WorldStateFact: Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: WorldStateFactKind
    public let tag: GameplayTag
    public let value: Int
    public let timeIndex: Int
    public let note: String

    public init(
        id: StableID,
        kind: WorldStateFactKind,
        tag: GameplayTag,
        value: Int,
        timeIndex: Int,
        note: String
    ) {
        self.id = id
        self.kind = kind
        self.tag = tag
        self.value = value
        self.timeIndex = max(timeIndex, 0)
        self.note = note
    }
}

public struct WorldStateLedger: Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let facts: [WorldStateFact]

    public init(worldSeed: WorldSeed, facts: [WorldStateFact] = []) {
        self.worldSeed = worldSeed
        self.facts = facts.sorted { lhs, rhs in
            if lhs.timeIndex != rhs.timeIndex {
                return lhs.timeIndex < rhs.timeIndex
            }

            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    public func recording(
        kind: WorldStateFactKind,
        tag: GameplayTag,
        value: Int = 1,
        timeIndex: Int,
        note: String = ""
    ) -> WorldStateLedger {
        let id = StableID.make(
            worldSeed: worldSeed,
            domain: .rpgLedger,
            values: [
                UInt64(bitPattern: Int64(timeIndex)),
                StableHash.make { builder in
                    builder.combine(kind.rawValue)
                    builder.combine(tag.rawValue)
                    builder.combine(value)
                    builder.combine(note)
                }.value,
            ]
        )
        let fact = WorldStateFact(
            id: id,
            kind: kind,
            tag: tag,
            value: value,
            timeIndex: timeIndex,
            note: note
        )

        return WorldStateLedger(worldSeed: worldSeed, facts: facts + [fact])
    }

    public func contains(tag: GameplayTag) -> Bool {
        facts.contains { $0.tag == tag }
    }

    public func totalValue(for tag: GameplayTag) -> Int {
        facts.filter { $0.tag == tag }.reduce(0) { $0 + $1.value }
    }

    public var compacted: WorldStateLedger {
        var latestByKindAndTag: [LedgerCompactionKey: WorldStateFact] = [:]

        for fact in facts {
            latestByKindAndTag[LedgerCompactionKey(kind: fact.kind, tag: fact.tag)] = fact
        }

        return WorldStateLedger(worldSeed: worldSeed, facts: Array(latestByKindAndTag.values))
    }
}

private struct LedgerCompactionKey: Hashable {
    let kind: WorldStateFactKind
    let tag: GameplayTag
}
