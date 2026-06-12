import Foundation

public enum SaveCoordinatorError: Error, Equatable, Sendable {
    case missingRegistryDomain(PersistenceDomain)
    case injectedCrash(SaveCrashInjectionPoint)
}

public enum SaveCrashInjectionPoint: String, CaseIterable, Codable, Sendable {
    case afterRegionFiles
    case afterJournalSnapshotsAndIndex
    case beforeManifestCommit
}

public struct AutosavePolicy: Hashable, Codable, Sendable {
    public let debounceSeconds: TimeInterval
    public let maxRegionsPerPass: Int
    public let snapshotRetentionPolicy: SnapshotRetentionPolicy

    public init(
        debounceSeconds: TimeInterval = 3,
        maxRegionsPerPass: Int = 2,
        snapshotRetentionPolicy: SnapshotRetentionPolicy = SnapshotRetentionPolicy()
    ) {
        precondition(debounceSeconds >= 0, "debounceSeconds must be non-negative.")
        precondition(maxRegionsPerPass > 0, "maxRegionsPerPass must be positive.")

        self.debounceSeconds = debounceSeconds
        self.maxRegionsPerPass = maxRegionsPerPass
        self.snapshotRetentionPolicy = snapshotRetentionPolicy
    }

    public func shouldAutosave(
        dirtyScope: DirtyScope,
        lastAutosaveAt: Date?,
        now: Date
    ) -> Bool {
        guard !dirtyScope.isEmpty else {
            return false
        }

        guard let lastAutosaveAt else {
            return true
        }

        return now.timeIntervalSince(lastAutosaveAt) >= debounceSeconds
    }

    public func scoped(_ dirtyScope: DirtyScope) -> DirtyScope {
        let includedRegions = Set(dirtyScope.dirtyRegions.prefix(maxRegionsPerPass))
        return DirtyScope(records: dirtyScope.records.filter { includedRegions.contains($0.region) })
    }
}

public struct SaveCoordinatorRequest: Sendable {
    public let manifest: SaveManifest
    public let player: SavePlayerState
    public let playTimeSeconds: Double
    public let dirtyTracker: DirtyTracker
    public let regionDeltaStore: RegionDeltaStore
    public let eventJournal: EventJournal
    public let snapshotStore: SnapshotStore
    public let entityStore: EntityStateStore?
    public let blobManifest: CASBlobManifest?
    public let tick: UInt64
    public let date: Date
    public let summary: String
    public let crashInjectionPoint: SaveCrashInjectionPoint?

    public init(
        manifest: SaveManifest,
        player: SavePlayerState,
        playTimeSeconds: Double,
        dirtyTracker: DirtyTracker,
        regionDeltaStore: RegionDeltaStore,
        eventJournal: EventJournal,
        snapshotStore: SnapshotStore,
        entityStore: EntityStateStore? = nil,
        blobManifest: CASBlobManifest? = nil,
        tick: UInt64,
        date: Date = Date(),
        summary: String,
        crashInjectionPoint: SaveCrashInjectionPoint? = nil
    ) {
        precondition(playTimeSeconds >= 0, "playTimeSeconds must be non-negative.")
        precondition(!summary.isEmpty, "summary cannot be empty.")

        self.manifest = manifest
        self.player = player
        self.playTimeSeconds = playTimeSeconds
        self.dirtyTracker = dirtyTracker
        self.regionDeltaStore = regionDeltaStore
        self.eventJournal = eventJournal
        self.snapshotStore = snapshotStore
        self.entityStore = entityStore
        self.blobManifest = blobManifest
        self.tick = tick
        self.date = date
        self.summary = summary
        self.crashInjectionPoint = crashInjectionPoint
    }
}

public struct SaveCoordinatorResult: Sendable {
    public let manifest: SaveManifest
    public let dirtyTracker: DirtyTracker
    public let eventJournal: EventJournal
    public let snapshotStore: SnapshotStore
    public let writtenRegionPaths: [String]
    public let manifestPath: String
    public let eventJournalPath: String
    public let snapshotIndexPath: String?
    public let entityStatePath: String?
    public let sqliteIndexPath: String?
    public let blobManifestPath: String?
    public let generation: Int

    public var wroteRegionDeltas: Bool {
        !writtenRegionPaths.isEmpty
    }
}

public actor SaveCoordinator {
    private let registry: PersistenceRegistry
    private let fileWriter: AtomicFileWriter
    private let regionFileStore: RegionDeltaFileStore
    private let entityStateFileStore: EntityStateFileStore
    private let sqliteIndexStore: SQLiteStateIndexStore
    private let blobStore: CASBlobStore
    private var lastAutosaveAt: Date?

    public init(
        registry: PersistenceRegistry = .productionV2,
        fileWriter: AtomicFileWriter = AtomicFileWriter(),
        entityStateFileStore: EntityStateFileStore = EntityStateFileStore(),
        sqliteIndexStore: SQLiteStateIndexStore = SQLiteStateIndexStore(),
        blobStore: CASBlobStore = CASBlobStore()
    ) {
        self.registry = registry
        self.fileWriter = fileWriter
        self.regionFileStore = RegionDeltaFileStore(fileWriter: fileWriter)
        self.entityStateFileStore = entityStateFileStore
        self.sqliteIndexStore = sqliteIndexStore
        self.blobStore = blobStore
    }

    public func save(
        _ request: SaveCoordinatorRequest,
        to rootURL: URL,
        snapshotRetentionPolicy: SnapshotRetentionPolicy = SnapshotRetentionPolicy()
    ) throws -> SaveCoordinatorResult {
        try performSave(
            request,
            reason: .manual,
            dirtyScope: request.dirtyTracker.dirtyScope(),
            rootURL: rootURL,
            snapshotRetentionPolicy: snapshotRetentionPolicy
        )
    }

    public func autosave(
        _ request: SaveCoordinatorRequest,
        policy: AutosavePolicy = AutosavePolicy(),
        to rootURL: URL
    ) throws -> SaveCoordinatorResult? {
        let dirtyScope = request.dirtyTracker.dirtyScope()

        guard policy.shouldAutosave(
            dirtyScope: dirtyScope,
            lastAutosaveAt: lastAutosaveAt,
            now: request.date
        ) else {
            return nil
        }

        let startedJournal = request.eventJournal.appending(
            kind: .autosaveStarted,
            tick: request.tick,
            date: request.date,
            summary: "Autosave started"
        )
        let scopedRequest = SaveCoordinatorRequest(
            manifest: request.manifest,
            player: request.player,
            playTimeSeconds: request.playTimeSeconds,
            dirtyTracker: request.dirtyTracker,
            regionDeltaStore: request.regionDeltaStore,
            eventJournal: startedJournal,
            snapshotStore: request.snapshotStore,
            entityStore: request.entityStore,
            blobManifest: request.blobManifest,
            tick: request.tick,
            date: request.date,
            summary: request.summary,
            crashInjectionPoint: request.crashInjectionPoint
        )
        let result = try performSave(
            scopedRequest,
            reason: .autosave,
            dirtyScope: policy.scoped(dirtyScope),
            rootURL: rootURL,
            snapshotRetentionPolicy: policy.snapshotRetentionPolicy
        )

        lastAutosaveAt = request.date
        return result
    }

    private func performSave(
        _ request: SaveCoordinatorRequest,
        reason: SnapshotReason,
        dirtyScope: DirtyScope,
        rootURL: URL,
        snapshotRetentionPolicy: SnapshotRetentionPolicy
    ) throws -> SaveCoordinatorResult {
        let files = try makeFilesManifest()
        let generation = request.manifest.integrity.generation + 1
        let regionFiles = regionFilesToWrite(
            store: request.regionDeltaStore,
            dirtyScope: dirtyScope,
            generation: generation
        )
        let writtenRegionPaths = try regionFileStore.write(regionFiles, relativeTo: rootURL)
        let savedScope = scope(forWrittenFiles: regionFiles, originalScope: dirtyScope)
        try crashIfNeeded(.afterRegionFiles, request: request)

        let savedManifest = request.manifest.saved(
            at: request.date,
            playTimeSeconds: request.playTimeSeconds,
            player: request.player,
            generation: generation,
            files: files
        )
        let journal = journalAfterSave(
            request.eventJournal,
            reason: reason,
            tick: request.tick,
            date: request.date,
            summary: request.summary,
            writtenRegions: regionFiles.map(\.region)
        )
        let snapshots = request.snapshotStore
            .recording(
                manifest: savedManifest,
            reason: reason,
            date: request.date,
            regionDeltaPaths: writtenRegionPaths,
            blobHashes: request.blobManifest?.blobs.map(\.hash) ?? [],
            summary: request.summary
        )
        .retained(policy: snapshotRetentionPolicy)
        let blobManifestPath = try request.blobManifest.map {
            try blobStore.writeManifest($0, relativeTo: rootURL)
        }
        let entityStatePath = try request.entityStore.map {
            try entityStateFileStore.write(
                $0,
                worldSeed: savedManifest.world.worldSeed,
                generation: generation,
                relativeTo: rootURL,
                relativePath: files.entityStatePath ?? EntityStateFileStore.defaultRelativePath
            )
        }
        try writeSnapshotStore(snapshots, rootURL: rootURL, snapshotsPath: files.snapshotsPath)
        try writeLatestSnapshot(from: snapshots, rootURL: rootURL)
        try fileWriter.writeJSON(journal, to: rootURL.appendingPathComponent(files.eventJournalPath ?? "events/journal.json"))
        let sqliteSummary = try sqliteIndexStore.write(
            SQLiteStateIndexSnapshot(
                manifest: savedManifest,
                eventJournal: journal,
                snapshotStore: snapshots,
                regionFiles: regionFiles,
                entityStore: request.entityStore,
                blobManifest: request.blobManifest
            ),
            relativeTo: rootURL
        )

        try crashIfNeeded(.afterJournalSnapshotsAndIndex, request: request)
        try crashIfNeeded(.beforeManifestCommit, request: request)
        try fileWriter.writeJSON(savedManifest, to: rootURL.appendingPathComponent(files.manifestPath))

        return SaveCoordinatorResult(
            manifest: savedManifest,
            dirtyTracker: request.dirtyTracker.markSaved(savedScope),
            eventJournal: journal,
            snapshotStore: snapshots,
            writtenRegionPaths: writtenRegionPaths,
            manifestPath: files.manifestPath,
            eventJournalPath: files.eventJournalPath ?? "events/journal.json",
            snapshotIndexPath: files.snapshotIndexPath,
            entityStatePath: entityStatePath,
            sqliteIndexPath: sqliteSummary.relativePath,
            blobManifestPath: blobManifestPath,
            generation: generation
        )
    }

    private func makeFilesManifest() throws -> SaveFilesManifest {
        SaveFilesManifest(
            manifestPath: try rootPath(for: .manifest),
            modifiedRegionsPath: try rootPath(for: .regionDeltas),
            blobsPath: try rootPath(for: .blobStore),
            snapshotsPath: try rootPath(for: .snapshots),
            eventJournalPath: try rootPath(for: .eventJournal),
            entityStatePath: try rootPath(for: .entityState),
            sqliteIndexPath: try rootPath(for: .sqliteIndex)
        )
    }

    private func rootPath(for domain: PersistenceDomain) throws -> String {
        guard let path = registry.rootPath(for: domain) else {
            throw SaveCoordinatorError.missingRegistryDomain(domain)
        }

        return path
    }

    private func regionFilesToWrite(
        store: RegionDeltaStore,
        dirtyScope: DirtyScope,
        generation: Int
    ) -> [RegionDeltaFile] {
        dirtyScope.dirtyRegions.compactMap { region in
            guard let file = store.file(for: region) else {
                return nil
            }

            return RegionDeltaFile(
                format: file.format,
                saveVersion: file.saveVersion,
                worldSeed: file.worldSeed,
                region: file.region,
                generation: generation,
                generatorVersionsHash: file.generatorVersionsHash,
                chunks: file.chunks
            )
        }
    }

    private func scope(
        forWrittenFiles files: [RegionDeltaFile],
        originalScope: DirtyScope
    ) -> DirtyScope {
        let writtenRegions = Set(files.map(\.region))
        return DirtyScope(records: originalScope.records.filter { writtenRegions.contains($0.region) })
    }

    private func journalAfterSave(
        _ journal: EventJournal,
        reason: SnapshotReason,
        tick: UInt64,
        date: Date,
        summary: String,
        writtenRegions: [RegionCoordinate]
    ) -> EventJournal {
        let withRegions = writtenRegions.sorted { lhs, rhs in
            if lhs.x != rhs.x { return lhs.x < rhs.x }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.z < rhs.z
        }.reduce(journal) { partial, region in
            partial.appending(
                kind: .chunkDeltaWritten,
                tick: tick,
                date: date,
                summary: "Region delta written",
                relatedRegion: region
            )
        }

        return withRegions.appending(
            kind: reason == .autosave ? .autosaveCommitted : .manualSaveCommitted,
            tick: tick,
            date: date,
            summary: summary
        )
    }

    private func writeSnapshotStore(
        _ store: SnapshotStore,
        rootURL: URL,
        snapshotsPath: String?
    ) throws {
        guard let snapshotsPath else {
            return
        }

        try fileWriter.writeJSON(
            store,
            to: rootURL.appendingPathComponent("\(snapshotsPath)/index.json")
        )
    }

    private func writeLatestSnapshot(
        from store: SnapshotStore,
        rootURL: URL
    ) throws {
        guard let snapshot = store.snapshots.last else {
            return
        }

        try fileWriter.writeJSON(snapshot, to: rootURL.appendingPathComponent(snapshot.relativePath))
    }

    private func crashIfNeeded(
        _ point: SaveCrashInjectionPoint,
        request: SaveCoordinatorRequest
    ) throws {
        guard request.crashInjectionPoint == point else {
            return
        }

        throw SaveCoordinatorError.injectedCrash(point)
    }
}
