import CSQLite
import Foundation

public enum SQLiteStateIndexError: Error, Equatable, Sendable {
    case openFailed(String)
    case executeFailed(String)
    case prepareFailed(String)
    case readFailed(String)
}

public struct SQLiteStateIndexSnapshot: Sendable {
    public let manifest: SaveManifest
    public let eventJournal: EventJournal
    public let snapshotStore: SnapshotStore
    public let regionFiles: [RegionDeltaFile]
    public let entityStore: EntityStateStore?
    public let blobManifest: CASBlobManifest?

    public init(
        manifest: SaveManifest,
        eventJournal: EventJournal,
        snapshotStore: SnapshotStore,
        regionFiles: [RegionDeltaFile],
        entityStore: EntityStateStore? = nil,
        blobManifest: CASBlobManifest? = nil
    ) {
        self.manifest = manifest
        self.eventJournal = eventJournal
        self.snapshotStore = snapshotStore
        self.regionFiles = regionFiles
        self.entityStore = entityStore
        self.blobManifest = blobManifest
    }
}

public struct SQLiteStateIndexSummary: Hashable, Codable, Sendable {
    public let relativePath: String
    public let journalMode: String
    public let userVersion: Int
    public let generation: Int
    public let entityCount: Int
    public let eventCount: Int
    public let regionFileCount: Int
    public let snapshotCount: Int
    public let blobCount: Int

    public var walEnabled: Bool {
        journalMode.lowercased() == "wal"
    }
}

public struct SQLiteStateIndexStore: Sendable {
    public static let defaultRelativePath = "state.sqlite"

    public let relativePath: String

    public init(relativePath: String = Self.defaultRelativePath) {
        precondition(!relativePath.isEmpty, "SQLite index relativePath cannot be empty.")

        self.relativePath = relativePath
    }

    public func write(
        _ snapshot: SQLiteStateIndexSnapshot,
        relativeTo rootURL: URL
    ) throws -> SQLiteStateIndexSummary {
        let url = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try withDatabase(at: url, createIfNeeded: true) { database in
            try configureForWrite(database)
            try createSchema(database)
            try execute("BEGIN IMMEDIATE TRANSACTION", database: database)

            do {
                try clearTables(database)
                try insert(snapshot, database: database)
                try execute("COMMIT", database: database)
            } catch {
                _ = try? execute("ROLLBACK", database: database)
                throw error
            }
        }

        return try readSummary(relativeTo: rootURL)
    }

    public func readSummary(relativeTo rootURL: URL) throws -> SQLiteStateIndexSummary {
        let url = rootURL.appendingPathComponent(relativePath)

        return try withDatabase(at: url, createIfNeeded: false) { database in
            return SQLiteStateIndexSummary(
                relativePath: relativePath,
                journalMode: try pragmaText("journal_mode", database: database),
                userVersion: try Int(pragmaInteger("user_version", database: database)),
                generation: try Int(metadataInteger("generation", database: database) ?? 0),
                entityCount: try Int(countRows(in: "entities", database: database)),
                eventCount: try Int(countRows(in: "events", database: database)),
                regionFileCount: try Int(countRows(in: "region_files", database: database)),
                snapshotCount: try Int(countRows(in: "snapshots", database: database)),
                blobCount: try Int(countRows(in: "blobs", database: database))
            )
        }
    }

    private func withDatabase<T>(
        at url: URL,
        createIfNeeded: Bool,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE
            | SQLITE_OPEN_FULLMUTEX
            | (createIfNeeded ? SQLITE_OPEN_CREATE : 0)
        let openCode = sqlite3_open_v2(url.path, &database, flags, nil)

        guard openCode == SQLITE_OK, let database else {
            let message = database.map(Self.errorMessage) ?? "Unable to open SQLite database."
            if let database {
                sqlite3_close(database)
            }
            throw SQLiteStateIndexError.openFailed(message)
        }

        defer {
            sqlite3_close(database)
        }

        return try body(database)
    }

    private func configureForWrite(_ database: OpaquePointer) throws {
        _ = try pragmaText("journal_mode = WAL", database: database)
        try execute("PRAGMA synchronous = NORMAL", database: database)
        try execute("PRAGMA foreign_keys = ON", database: database)
        try execute("PRAGMA user_version = 2", database: database)
    }

    private func createSchema(_ database: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS save_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS region_files (
                path TEXT PRIMARY KEY,
                generation INTEGER NOT NULL,
                region_x INTEGER NOT NULL,
                region_y INTEGER NOT NULL,
                region_z INTEGER NOT NULL,
                modified_chunks INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS events (
                sequence INTEGER PRIMARY KEY,
                kind TEXT NOT NULL,
                tick INTEGER NOT NULL,
                date TEXT NOT NULL,
                summary TEXT NOT NULL,
                region_x INTEGER,
                region_y INTEGER,
                region_z INTEGER
            );
            CREATE TABLE IF NOT EXISTS snapshots (
                generation INTEGER PRIMARY KEY,
                reason TEXT NOT NULL,
                path TEXT NOT NULL,
                created_at TEXT NOT NULL,
                region_delta_count INTEGER NOT NULL,
                blob_count INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS entities (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                region_x INTEGER NOT NULL,
                region_y INTEGER NOT NULL,
                region_z INTEGER NOT NULL,
                chunk_x INTEGER NOT NULL,
                chunk_y INTEGER NOT NULL,
                chunk_z INTEGER NOT NULL,
                removed INTEGER NOT NULL,
                tick INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS blobs (
                hash TEXT PRIMARY KEY,
                path TEXT NOT NULL,
                kind TEXT NOT NULL,
                byte_count INTEGER NOT NULL
            );
            """,
            database: database
        )
    }

    private func clearTables(_ database: OpaquePointer) throws {
        for table in ["save_metadata", "region_files", "events", "snapshots", "entities", "blobs"] {
            try execute("DELETE FROM \(table)", database: database)
        }
    }

    private func insert(
        _ snapshot: SQLiteStateIndexSnapshot,
        database: OpaquePointer
    ) throws {
        let manifest = snapshot.manifest
        try insertMetadata("slot_id", manifest.slotID.rawValue, database: database)
        try insertMetadata("generation", "\(manifest.integrity.generation)", database: database)
        try insertMetadata("save_version", manifest.saveVersion.description, database: database)
        try insertMetadata("world_seed", "\(manifest.world.worldSeed.value)", database: database)
        try insertMetadata("manifest_path", manifest.files.manifestPath, database: database)

        for file in snapshot.regionFiles {
            try execute(
                """
                INSERT INTO region_files VALUES (
                    \(quote(file.relativePath)),
                    \(file.generation),
                    \(file.region.x),
                    \(file.region.y),
                    \(file.region.z),
                    \(file.modifiedChunkCount)
                )
                """,
                database: database
            )
        }

        for entry in snapshot.eventJournal.entries {
            try execute(
                """
                INSERT INTO events VALUES (
                    \(entry.sequence),
                    \(quote(entry.kind.rawValue)),
                    \(entry.tick),
                    \(quote(iso8601String(from: entry.date))),
                    \(quote(entry.summary)),
                    \(optionalInteger(entry.relatedRegion?.x)),
                    \(optionalInteger(entry.relatedRegion?.y)),
                    \(optionalInteger(entry.relatedRegion?.z))
                )
                """,
                database: database
            )
        }

        for snapshotManifest in snapshot.snapshotStore.snapshots {
            try execute(
                """
                INSERT INTO snapshots VALUES (
                    \(snapshotManifest.generation),
                    \(quote(snapshotManifest.reason.rawValue)),
                    \(quote(snapshotManifest.relativePath)),
                    \(quote(iso8601String(from: snapshotManifest.createdAt))),
                    \(snapshotManifest.regionDeltaPaths.count),
                    \(snapshotManifest.blobHashes.count)
                )
                """,
                database: database
            )
        }

        for entity in snapshot.entityStore?.entities ?? [] {
            try execute(
                """
                INSERT INTO entities VALUES (
                    \(quote(entity.id.description)),
                    \(quote(entity.kind.rawValue)),
                    \(entity.region.x),
                    \(entity.region.y),
                    \(entity.region.z),
                    \(entity.chunk.x),
                    \(entity.chunk.y),
                    \(entity.chunk.z),
                    \(entity.isRemoved ? 1 : 0),
                    \(entity.lastModifiedTick)
                )
                """,
                database: database
            )
        }

        for blob in snapshot.blobManifest?.blobs ?? [] {
            try execute(
                """
                INSERT INTO blobs VALUES (
                    \(quote(blob.hash)),
                    \(quote(blob.relativePath)),
                    \(quote(blob.kind.rawValue)),
                    \(blob.byteCount)
                )
                """,
                database: database
            )
        }
    }

    private func insertMetadata(
        _ key: String,
        _ value: String,
        database: OpaquePointer
    ) throws {
        try execute(
            "INSERT INTO save_metadata VALUES (\(quote(key)), \(quote(value)))",
            database: database
        )
    }

    @discardableResult
    private func execute(
        _ sql: String,
        database: OpaquePointer
    ) throws -> String? {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(database, sql, nil, nil, &errorMessage)

        guard code == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? Self.errorMessage(database)
            sqlite3_free(errorMessage)
            throw SQLiteStateIndexError.executeFailed(message)
        }

        sqlite3_free(errorMessage)
        return nil
    }

    private func pragmaText(
        _ pragma: String,
        database: OpaquePointer
    ) throws -> String {
        try queryText("PRAGMA \(pragma)", database: database) ?? ""
    }

    private func pragmaInteger(
        _ pragma: String,
        database: OpaquePointer
    ) throws -> Int64 {
        try queryInteger("PRAGMA \(pragma)", database: database) ?? 0
    }

    private func metadataInteger(
        _ key: String,
        database: OpaquePointer
    ) throws -> Int64? {
        guard let value = try queryText(
            "SELECT value FROM save_metadata WHERE key = \(quote(key))",
            database: database
        ) else {
            return nil
        }

        return Int64(value)
    }

    private func countRows(
        in table: String,
        database: OpaquePointer
    ) throws -> Int64 {
        try queryInteger("SELECT COUNT(*) FROM \(table)", database: database) ?? 0
    }

    private func queryText(
        _ sql: String,
        database: OpaquePointer
    ) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStateIndexError.prepareFailed(Self.errorMessage(database))
        }

        defer {
            sqlite3_finalize(statement)
        }

        let stepCode = sqlite3_step(statement)
        guard stepCode == SQLITE_ROW else {
            if stepCode == SQLITE_DONE {
                return nil
            }

            throw SQLiteStateIndexError.readFailed(Self.errorMessage(database))
        }

        guard let text = sqlite3_column_text(statement, 0) else {
            return nil
        }

        return String(cString: text)
    }

    private func queryInteger(
        _ sql: String,
        database: OpaquePointer
    ) throws -> Int64? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStateIndexError.prepareFailed(Self.errorMessage(database))
        }

        defer {
            sqlite3_finalize(statement)
        }

        let stepCode = sqlite3_step(statement)
        guard stepCode == SQLITE_ROW else {
            if stepCode == SQLITE_DONE {
                return nil
            }

            throw SQLiteStateIndexError.readFailed(Self.errorMessage(database))
        }

        return sqlite3_column_int64(statement, 0)
    }

    private func quote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    private func optionalInteger(_ value: Int?) -> String {
        value.map(String.init) ?? "NULL"
    }

    private func iso8601String(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func errorMessage(_ database: OpaquePointer) -> String {
        sqlite3_errmsg(database).map { String(cString: $0) } ?? "Unknown SQLite error."
    }
}
