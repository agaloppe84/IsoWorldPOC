import Foundation

public enum SaveRecoveryStatus: String, CaseIterable, Codable, Sendable {
    case clean
    case needsRollback
    case missingManifest
    case corrupt
}

public struct SaveRecoveryReport: Hashable, Codable, Sendable {
    public let status: SaveRecoveryStatus
    public let latestCommittedGeneration: Int?
    public let inspectedRegionFileCount: Int
    public let inspectedSnapshotFileCount: Int
    public let orphanRegionFileCount: Int
    public let orphanSnapshotFileCount: Int
    public let orphanRelativePaths: [String]
    public let issues: [String]

    public var canRecover: Bool {
        status == .clean || status == .needsRollback
    }

    public init(
        status: SaveRecoveryStatus,
        latestCommittedGeneration: Int?,
        inspectedRegionFileCount: Int,
        inspectedSnapshotFileCount: Int,
        orphanRegionFileCount: Int,
        orphanSnapshotFileCount: Int,
        orphanRelativePaths: [String],
        issues: [String]
    ) {
        self.status = status
        self.latestCommittedGeneration = latestCommittedGeneration
        self.inspectedRegionFileCount = inspectedRegionFileCount
        self.inspectedSnapshotFileCount = inspectedSnapshotFileCount
        self.orphanRegionFileCount = orphanRegionFileCount
        self.orphanSnapshotFileCount = orphanSnapshotFileCount
        self.orphanRelativePaths = orphanRelativePaths.sorted()
        self.issues = issues
    }
}

public struct SaveRecoveryScanner: Sendable {
    private let fileWriter: AtomicFileWriter

    public init(fileWriter: AtomicFileWriter = AtomicFileWriter()) {
        self.fileWriter = fileWriter
    }

    public func scan(rootURL: URL) -> SaveRecoveryReport {
        let manifestURL = rootURL.appendingPathComponent("manifest.json")
        let manifest: SaveManifest?

        if FileManager.default.fileExists(atPath: manifestURL.path) {
            do {
                manifest = try fileWriter.readJSON(SaveManifest.self, from: manifestURL)
            } catch {
                return SaveRecoveryReport(
                    status: .corrupt,
                    latestCommittedGeneration: nil,
                    inspectedRegionFileCount: 0,
                    inspectedSnapshotFileCount: 0,
                    orphanRegionFileCount: 0,
                    orphanSnapshotFileCount: 0,
                    orphanRelativePaths: [],
                    issues: ["manifest.json is corrupt: \(error)"]
                )
            }
        } else {
            manifest = nil
        }

        let regionFiles = loadRegionFiles(rootURL: rootURL)
        let snapshotFiles = loadSnapshotFiles(rootURL: rootURL)
        let generation = manifest?.integrity.generation
        let orphanSupportPaths = supportArtifactOrphanPaths(
            rootURL: rootURL,
            manifest: manifest,
            committedGeneration: generation,
            manifestURL: manifestURL
        )
        let orphanRegions = regionFiles.filter { file in
            guard let generation else {
                return true
            }

            return file.generation > generation
        }
        let orphanSnapshots = snapshotFiles.filter { snapshot in
            guard let generation else {
                return true
            }

            return snapshot.generation > generation
        }
        let orphanPaths = (
            orphanRegions.map(\.relativePath)
                + orphanSnapshots.map(\.relativePath)
                + orphanSupportPaths
        ).sorted()
        var issues: [String] = []

        if manifest == nil, !regionFiles.isEmpty || !snapshotFiles.isEmpty || !orphanSupportPaths.isEmpty {
            issues.append("Save artifacts exist without a committed manifest.")
        }

        if !orphanRegions.isEmpty {
            issues.append("\(orphanRegions.count) region file(s) are newer than the committed manifest.")
        }

        if !orphanSnapshots.isEmpty {
            issues.append("\(orphanSnapshots.count) snapshot file(s) are newer than the committed manifest.")
        }

        if !orphanSupportPaths.isEmpty {
            issues.append("\(orphanSupportPaths.count) support artifact(s) are newer than the committed manifest.")
        }

        let status: SaveRecoveryStatus
        if manifest == nil {
            status = orphanPaths.isEmpty ? .missingManifest : .missingManifest
        } else if orphanPaths.isEmpty {
            status = .clean
        } else {
            status = .needsRollback
        }

        return SaveRecoveryReport(
            status: status,
            latestCommittedGeneration: generation,
            inspectedRegionFileCount: regionFiles.count,
            inspectedSnapshotFileCount: snapshotFiles.count,
            orphanRegionFileCount: orphanRegions.count,
            orphanSnapshotFileCount: orphanSnapshots.count,
            orphanRelativePaths: orphanPaths,
            issues: issues
        )
    }

    public func rollbackUncommittedArtifacts(rootURL: URL) throws -> SaveRecoveryReport {
        let report = scan(rootURL: rootURL)

        for path in report.orphanRelativePaths {
            let url = rootURL.appendingPathComponent(path)

            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }

        return scan(rootURL: rootURL)
    }

    private func loadRegionFiles(rootURL: URL) -> [RegionDeltaFile] {
        files(
            rootURL: rootURL.appendingPathComponent("regions", isDirectory: true),
            suffix: ".isoregion"
        ).compactMap { url in
            try? fileWriter.readJSON(RegionDeltaFile.self, from: url)
        }
    }

    private func loadSnapshotFiles(rootURL: URL) -> [SaveSnapshotManifest] {
        files(
            rootURL: rootURL.appendingPathComponent("snapshots", isDirectory: true),
            suffix: ".isosnapshot"
        ).compactMap { url in
            try? fileWriter.readJSON(SaveSnapshotManifest.self, from: url)
        }
    }

    private func supportArtifactOrphanPaths(
        rootURL: URL,
        manifest: SaveManifest?,
        committedGeneration: Int?,
        manifestURL: URL
    ) -> [String] {
        let files = manifest?.files ?? .productionV2
        let fallbackFiles = SaveFilesManifest.productionV2
        var paths = Set<String>()

        if let sqliteIndexPath = files.sqliteIndexPath ?? fallbackFiles.sqliteIndexPath,
           sqliteIndexIsAhead(
               relativePath: sqliteIndexPath,
               rootURL: rootURL,
               committedGeneration: committedGeneration
           ) {
            for path in sqliteSidecarPaths(relativePath: sqliteIndexPath, rootURL: rootURL) {
                paths.insert(path)
            }
        }

        if let snapshotIndexPath = files.snapshotIndexPath ?? fallbackFiles.snapshotIndexPath,
           snapshotIndexIsAhead(
               relativePath: snapshotIndexPath,
               rootURL: rootURL,
               committedGeneration: committedGeneration
           ) {
            paths.insert(snapshotIndexPath)
        }

        if let eventJournalPath = files.eventJournalPath ?? fallbackFiles.eventJournalPath,
           eventJournalIsAhead(
               relativePath: eventJournalPath,
               rootURL: rootURL,
               manifestURL: manifestURL,
               committedGeneration: committedGeneration
        ) {
            paths.insert(eventJournalPath)
        }

        if let entityStatePath = files.entityStatePath ?? fallbackFiles.entityStatePath,
           fileIsNewerThanManifestOrMissingManifest(
               relativePath: entityStatePath,
               rootURL: rootURL,
               manifestURL: manifestURL,
               committedGeneration: committedGeneration
           ) {
            paths.insert(entityStatePath)
        }

        return paths.sorted()
    }

    private func sqliteIndexIsAhead(
        relativePath: String,
        rootURL: URL,
        committedGeneration: Int?
    ) -> Bool {
        let url = rootURL.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard let committedGeneration else {
            return true
        }

        let summary = try? SQLiteStateIndexStore(relativePath: relativePath)
            .readSummary(relativeTo: rootURL)
        return (summary?.generation ?? committedGeneration) > committedGeneration
    }

    private func snapshotIndexIsAhead(
        relativePath: String,
        rootURL: URL,
        committedGeneration: Int?
    ) -> Bool {
        let url = rootURL.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard let committedGeneration else {
            return true
        }

        let store = try? fileWriter.readJSON(SnapshotStore.self, from: url)
        return store?.snapshots.contains { $0.generation > committedGeneration } == true
    }

    private func eventJournalIsAhead(
        relativePath: String,
        rootURL: URL,
        manifestURL: URL,
        committedGeneration: Int?
    ) -> Bool {
        let url = rootURL.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard committedGeneration != nil else {
            return true
        }

        guard let eventDate = modificationDate(for: url),
              let manifestDate = modificationDate(for: manifestURL) else {
            return false
        }

        return eventDate > manifestDate
    }

    private func fileIsNewerThanManifestOrMissingManifest(
        relativePath: String,
        rootURL: URL,
        manifestURL: URL,
        committedGeneration: Int?
    ) -> Bool {
        let url = rootURL.appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        guard committedGeneration != nil else {
            return true
        }

        guard let fileDate = modificationDate(for: url),
              let manifestDate = modificationDate(for: manifestURL) else {
            return false
        }

        return fileDate > manifestDate
    }

    private func sqliteSidecarPaths(relativePath: String, rootURL: URL) -> [String] {
        [relativePath, "\(relativePath)-wal", "\(relativePath)-shm"].filter { path in
            FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(path).path)
        }
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func files(rootURL: URL, suffix: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.lastPathComponent.hasSuffix(suffix) else {
                return nil
            }

            return url
        }
        .sorted { $0.path < $1.path }
    }
}
