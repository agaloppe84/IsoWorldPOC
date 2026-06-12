public enum DirtyReason: String, CaseIterable, Codable, Sendable {
    case terrainDelta
    case propDelta
    case entityState
    case settlementDelta
    case toolProject
    case assetPackage
    case graphPackage
    case snapshot
    case event
}

public struct DirtyChunkRecord: Hashable, Codable, Sendable {
    public let coordinate: ChunkCoordinate
    public let region: RegionCoordinate
    public let firstDirtyTick: UInt64
    public let lastDirtyTick: UInt64
    public let systemIDs: [String]
    public let reasons: [DirtyReason]

    public init(
        coordinate: ChunkCoordinate,
        region: RegionCoordinate,
        firstDirtyTick: UInt64,
        lastDirtyTick: UInt64,
        systemIDs: [String],
        reasons: [DirtyReason]
    ) {
        precondition(firstDirtyTick <= lastDirtyTick, "Dirty record ticks must be ordered.")
        precondition(!systemIDs.contains(where: \.isEmpty), "Dirty system IDs cannot be empty.")
        precondition(!reasons.isEmpty, "Dirty record needs at least one reason.")

        self.coordinate = coordinate
        self.region = region
        self.firstDirtyTick = firstDirtyTick
        self.lastDirtyTick = lastDirtyTick
        self.systemIDs = Self.uniquedSorted(systemIDs)
        self.reasons = Self.uniquedStable(reasons)
    }

    public func merging(
        tick: UInt64,
        systemID: String,
        reason: DirtyReason
    ) -> DirtyChunkRecord {
        DirtyChunkRecord(
            coordinate: coordinate,
            region: region,
            firstDirtyTick: min(firstDirtyTick, tick),
            lastDirtyTick: max(lastDirtyTick, tick),
            systemIDs: systemIDs + [systemID],
            reasons: reasons + [reason]
        )
    }

    private static func uniquedSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted()
    }

    private static func uniquedStable(_ values: [DirtyReason]) -> [DirtyReason] {
        var seen: Set<DirtyReason> = []
        var result: [DirtyReason] = []

        for value in values where seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }
}

public struct DirtyScope: Hashable, Codable, Sendable {
    public let records: [DirtyChunkRecord]

    public init(records: [DirtyChunkRecord]) {
        self.records = records.sorted { lhs, rhs in
            if lhs.region.x != rhs.region.x { return lhs.region.x < rhs.region.x }
            if lhs.region.y != rhs.region.y { return lhs.region.y < rhs.region.y }
            if lhs.region.z != rhs.region.z { return lhs.region.z < rhs.region.z }
            if lhs.coordinate.x != rhs.coordinate.x { return lhs.coordinate.x < rhs.coordinate.x }
            if lhs.coordinate.y != rhs.coordinate.y { return lhs.coordinate.y < rhs.coordinate.y }
            return lhs.coordinate.z < rhs.coordinate.z
        }
    }

    public var isEmpty: Bool {
        records.isEmpty
    }

    public var dirtyRegions: [RegionCoordinate] {
        var seen: Set<RegionCoordinate> = []
        var regions: [RegionCoordinate] = []

        for record in records where seen.insert(record.region).inserted {
            regions.append(record.region)
        }

        return regions
    }

    public func records(in region: RegionCoordinate) -> [DirtyChunkRecord] {
        records.filter { $0.region == region }
    }
}

public struct DirtyTracker: Hashable, Codable, Sendable {
    public let regionSizeInChunks: Int
    public let records: [DirtyChunkRecord]
    public let lastSavedTick: UInt64

    public init(
        regionSizeInChunks: Int = 8,
        records: [DirtyChunkRecord] = [],
        lastSavedTick: UInt64 = 0
    ) {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive.")

        self.regionSizeInChunks = regionSizeInChunks
        self.records = Self.merged(records)
        self.lastSavedTick = lastSavedTick
    }

    public func markingDirty(
        coordinate: ChunkCoordinate,
        tick: UInt64,
        systemID: String,
        reason: DirtyReason
    ) -> DirtyTracker {
        precondition(!systemID.isEmpty, "systemID cannot be empty.")

        let region = RegionCoordinate.containing(
            coordinate,
            regionSizeInChunks: regionSizeInChunks
        )
        let newRecord = DirtyChunkRecord(
            coordinate: coordinate,
            region: region,
            firstDirtyTick: tick,
            lastDirtyTick: tick,
            systemIDs: [systemID],
            reasons: [reason]
        )

        return DirtyTracker(
            regionSizeInChunks: regionSizeInChunks,
            records: records + [newRecord],
            lastSavedTick: lastSavedTick
        )
    }

    public func dirtyScope(since tick: UInt64? = nil) -> DirtyScope {
        let lowerBound = tick ?? lastSavedTick
        return DirtyScope(records: records.filter { $0.lastDirtyTick > lowerBound })
    }

    public func markSaved(upTo tick: UInt64) -> DirtyTracker {
        DirtyTracker(
            regionSizeInChunks: regionSizeInChunks,
            records: records.filter { $0.lastDirtyTick > tick },
            lastSavedTick: max(lastSavedTick, tick)
        )
    }

    private static func merged(_ records: [DirtyChunkRecord]) -> [DirtyChunkRecord] {
        var byCoordinate: [ChunkCoordinate: DirtyChunkRecord] = [:]

        for record in records {
            if let existing = byCoordinate[record.coordinate] {
                byCoordinate[record.coordinate] = DirtyChunkRecord(
                    coordinate: existing.coordinate,
                    region: existing.region,
                    firstDirtyTick: min(existing.firstDirtyTick, record.firstDirtyTick),
                    lastDirtyTick: max(existing.lastDirtyTick, record.lastDirtyTick),
                    systemIDs: existing.systemIDs + record.systemIDs,
                    reasons: existing.reasons + record.reasons
                )
            } else {
                byCoordinate[record.coordinate] = record
            }
        }

        return DirtyScope(records: Array(byCoordinate.values)).records
    }
}
