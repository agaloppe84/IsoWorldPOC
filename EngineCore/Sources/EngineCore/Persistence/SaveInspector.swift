import Foundation

public enum SaveInspectionStatus: String, CaseIterable, Codable, Sendable {
    case ready
    case missing
    case needsRecovery
    case corrupt
}

public struct SaveInspectionReport: Hashable, Codable, Sendable {
    public let sourcePath: String
    public let status: SaveInspectionStatus
    public let manifestGeneration: Int?
    public let regionFileCount: Int
    public let eventCount: Int
    public let snapshotCount: Int
    public let blobCount: Int
    public let sqliteSummary: SQLiteStateIndexSummary?
    public let recoveryReport: SaveRecoveryReport

    public var walEnabled: Bool {
        sqliteSummary?.walEnabled == true
    }

    public init(
        sourcePath: String,
        status: SaveInspectionStatus,
        manifestGeneration: Int?,
        regionFileCount: Int,
        eventCount: Int,
        snapshotCount: Int,
        blobCount: Int,
        sqliteSummary: SQLiteStateIndexSummary?,
        recoveryReport: SaveRecoveryReport
    ) {
        self.sourcePath = sourcePath
        self.status = status
        self.manifestGeneration = manifestGeneration
        self.regionFileCount = regionFileCount
        self.eventCount = eventCount
        self.snapshotCount = snapshotCount
        self.blobCount = blobCount
        self.sqliteSummary = sqliteSummary
        self.recoveryReport = recoveryReport
    }

    public static func preview(
        sourcePath: String = "preview://save-inspector",
        generation: Int = 1,
        regionFileCount: Int = 1,
        eventCount: Int = 2,
        snapshotCount: Int = 1,
        blobCount: Int = 0
    ) -> SaveInspectionReport {
        SaveInspectionReport(
            sourcePath: sourcePath,
            status: .ready,
            manifestGeneration: generation,
            regionFileCount: regionFileCount,
            eventCount: eventCount,
            snapshotCount: snapshotCount,
            blobCount: blobCount,
            sqliteSummary: nil,
            recoveryReport: SaveRecoveryReport(
                status: .clean,
                latestCommittedGeneration: generation,
                inspectedRegionFileCount: regionFileCount,
                inspectedSnapshotFileCount: snapshotCount,
                orphanRegionFileCount: 0,
                orphanSnapshotFileCount: 0,
                orphanRelativePaths: [],
                issues: []
            )
        )
    }
}

public struct SaveInspector: Sendable {
    private let fileWriter: AtomicFileWriter
    private let sqliteIndexStore: SQLiteStateIndexStore
    private let recoveryScanner: SaveRecoveryScanner

    public init(
        fileWriter: AtomicFileWriter = AtomicFileWriter(),
        sqliteIndexStore: SQLiteStateIndexStore = SQLiteStateIndexStore(),
        recoveryScanner: SaveRecoveryScanner = SaveRecoveryScanner()
    ) {
        self.fileWriter = fileWriter
        self.sqliteIndexStore = sqliteIndexStore
        self.recoveryScanner = recoveryScanner
    }

    public func inspect(rootURL: URL) -> SaveInspectionReport {
        let recovery = recoveryScanner.scan(rootURL: rootURL)
        let manifest = try? fileWriter.readJSON(
            SaveManifest.self,
            from: rootURL.appendingPathComponent("manifest.json")
        )
        let journal = manifest.flatMap { manifest in
            manifest.files.eventJournalPath.flatMap { path in
                try? fileWriter.readJSON(EventJournal.self, from: rootURL.appendingPathComponent(path))
            }
        }
        let snapshots = manifest.flatMap { manifest in
            manifest.files.snapshotIndexPath.flatMap { path in
                try? fileWriter.readJSON(SnapshotStore.self, from: rootURL.appendingPathComponent(path))
            }
        }
        let blobManifest = try? CASBlobStore().readManifest(relativeTo: rootURL)
        let sqliteSummary = try? sqliteIndexStore.readSummary(relativeTo: rootURL)
        let status: SaveInspectionStatus

        switch recovery.status {
        case .clean:
            status = manifest == nil ? .missing : .ready
        case .needsRollback:
            status = .needsRecovery
        case .missingManifest:
            status = .missing
        case .corrupt:
            status = .corrupt
        }

        return SaveInspectionReport(
            sourcePath: rootURL.path,
            status: status,
            manifestGeneration: manifest?.integrity.generation,
            regionFileCount: recovery.inspectedRegionFileCount,
            eventCount: journal?.entries.count ?? sqliteSummary?.eventCount ?? 0,
            snapshotCount: snapshots?.snapshots.count ?? sqliteSummary?.snapshotCount ?? 0,
            blobCount: blobManifest?.blobs.count ?? sqliteSummary?.blobCount ?? 0,
            sqliteSummary: sqliteSummary,
            recoveryReport: recovery
        )
    }
}
