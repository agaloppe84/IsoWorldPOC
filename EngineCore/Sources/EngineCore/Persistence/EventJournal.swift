import Foundation

public enum SaveEventKind: String, CaseIterable, Codable, Sendable {
    case worldCreated
    case autosaveStarted
    case autosaveCommitted
    case manualSaveCommitted
    case chunkDeltaWritten
    case entityUpserted
    case entityRemoved
    case snapshotCaptured
    case migrationStarted
    case migrationCompleted
    case toolProjectSaved
    case assetExported
}

public struct SaveEventJournalEntry: Hashable, Codable, Sendable {
    public let id: StableID
    public let sequence: UInt64
    public let tick: UInt64
    public let date: Date
    public let kind: SaveEventKind
    public let summary: String
    public let relatedRegion: RegionCoordinate?
    public let relatedEntityID: StableID?
    public let tags: [GameplayTag]

    public init(
        id: StableID,
        sequence: UInt64,
        tick: UInt64,
        date: Date,
        kind: SaveEventKind,
        summary: String,
        relatedRegion: RegionCoordinate? = nil,
        relatedEntityID: StableID? = nil,
        tags: [GameplayTag] = []
    ) {
        precondition(!summary.isEmpty, "Save event summary cannot be empty.")

        self.id = id
        self.sequence = sequence
        self.tick = tick
        self.date = date
        self.kind = kind
        self.summary = summary
        self.relatedRegion = relatedRegion
        self.relatedEntityID = relatedEntityID
        self.tags = tags.uniquedStable()
    }
}

public struct EventJournal: Hashable, Codable, Sendable {
    public let slotID: SaveSlotID
    public let entries: [SaveEventJournalEntry]

    public init(
        slotID: SaveSlotID,
        entries: [SaveEventJournalEntry] = []
    ) {
        self.slotID = slotID
        self.entries = entries.sorted { lhs, rhs in
            if lhs.sequence != rhs.sequence {
                return lhs.sequence < rhs.sequence
            }

            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    public var nextSequence: UInt64 {
        (entries.map(\.sequence).max() ?? 0) + 1
    }

    public func appending(
        kind: SaveEventKind,
        tick: UInt64,
        date: Date,
        summary: String,
        relatedRegion: RegionCoordinate? = nil,
        relatedEntityID: StableID? = nil,
        tags: [GameplayTag] = []
    ) -> EventJournal {
        let sequence = nextSequence
        let id = StableID.make(
            worldSeed: WorldSeed(StableHash.make { builder in
                builder.combine(slotID.rawValue)
            }.value),
            domain: .entities,
            values: [
                StableHash.make { builder in
                    builder.combine("event-journal")
                    builder.combine(sequence)
                    builder.combine(kind.rawValue)
                }.value,
            ]
        )
        let entry = SaveEventJournalEntry(
            id: id,
            sequence: sequence,
            tick: tick,
            date: date,
            kind: kind,
            summary: summary,
            relatedRegion: relatedRegion,
            relatedEntityID: relatedEntityID,
            tags: tags
        )

        return EventJournal(slotID: slotID, entries: entries + [entry])
    }

    public func entries(since tick: UInt64) -> [SaveEventJournalEntry] {
        entries.filter { $0.tick > tick }
    }

    public func compacted(keepingLast count: Int) -> EventJournal {
        precondition(count >= 0, "count must be non-negative.")

        guard entries.count > count else {
            return self
        }

        return EventJournal(slotID: slotID, entries: Array(entries.suffix(count)))
    }
}
