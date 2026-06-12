import Foundation

public enum SnapshotReason: String, CaseIterable, Codable, Sendable {
    case manual
    case autosave
    case checkpoint
    case preMigration
    case toolRevision
}

public struct SaveSnapshotManifest: Hashable, Codable, Sendable {
    public let id: StableID
    public let slotID: SaveSlotID
    public let generation: Int
    public let createdAt: Date
    public let reason: SnapshotReason
    public let worldSeed: WorldSeed
    public let playerPosition: WorldPosition
    public let manifestPath: String
    public let regionDeltaPaths: [String]
    public let blobHashes: [String]
    public let summary: String
    public let checksum: StableHash

    public init(
        id: StableID,
        slotID: SaveSlotID,
        generation: Int,
        createdAt: Date,
        reason: SnapshotReason,
        worldSeed: WorldSeed,
        playerPosition: WorldPosition,
        manifestPath: String,
        regionDeltaPaths: [String] = [],
        blobHashes: [String] = [],
        summary: String
    ) {
        precondition(generation >= 0, "generation must be non-negative.")
        precondition(!manifestPath.isEmpty, "manifestPath cannot be empty.")
        precondition(!summary.isEmpty, "summary cannot be empty.")

        self.id = id
        self.slotID = slotID
        self.generation = generation
        self.createdAt = createdAt
        self.reason = reason
        self.worldSeed = worldSeed
        self.playerPosition = playerPosition
        self.manifestPath = manifestPath
        self.regionDeltaPaths = regionDeltaPaths.sorted()
        self.blobHashes = blobHashes.sorted()
        self.summary = summary
        self.checksum = StableHash.make { builder in
            builder.combine(slotID.rawValue)
            builder.combine(generation)
            builder.combine(reason.rawValue)
            builder.combine(worldSeed)
            builder.combine(playerPosition.x)
            builder.combine(playerPosition.y)
            builder.combine(playerPosition.z)
            builder.combine(manifestPath)

            for path in regionDeltaPaths.sorted() {
                builder.combine(path)
            }

            for hash in blobHashes.sorted() {
                builder.combine(hash)
            }
        }
    }

    public var relativePath: String {
        "snapshots/\(generation).isosnapshot"
    }
}

public struct SnapshotRetentionPolicy: Hashable, Codable, Sendable {
    public let autosaveLimit: Int
    public let manualLimit: Int
    public let checkpointLimit: Int
    public let keepPreMigration: Bool

    public init(
        autosaveLimit: Int = 3,
        manualLimit: Int = 3,
        checkpointLimit: Int = 1,
        keepPreMigration: Bool = true
    ) {
        precondition(autosaveLimit >= 0, "autosaveLimit must be non-negative.")
        precondition(manualLimit >= 0, "manualLimit must be non-negative.")
        precondition(checkpointLimit >= 0, "checkpointLimit must be non-negative.")

        self.autosaveLimit = autosaveLimit
        self.manualLimit = manualLimit
        self.checkpointLimit = checkpointLimit
        self.keepPreMigration = keepPreMigration
    }
}

public struct SnapshotStore: Hashable, Codable, Sendable {
    public let slotID: SaveSlotID
    public let snapshots: [SaveSnapshotManifest]

    public init(
        slotID: SaveSlotID,
        snapshots: [SaveSnapshotManifest] = []
    ) {
        self.slotID = slotID
        self.snapshots = snapshots.sorted { lhs, rhs in
            if lhs.generation != rhs.generation {
                return lhs.generation < rhs.generation
            }

            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    public func recording(
        manifest: SaveManifest,
        reason: SnapshotReason,
        date: Date,
        regionDeltaPaths: [String] = [],
        blobHashes: [String] = [],
        summary: String
    ) -> SnapshotStore {
        let id = StableID.make(
            worldSeed: manifest.world.worldSeed,
            domain: .rpgLedger,
            values: [
                StableHash.make { builder in
                    builder.combine("snapshot")
                    builder.combine(manifest.slotID.rawValue)
                    builder.combine(manifest.integrity.generation)
                    builder.combine(reason.rawValue)
                }.value,
            ]
        )
        let snapshot = SaveSnapshotManifest(
            id: id,
            slotID: manifest.slotID,
            generation: manifest.integrity.generation,
            createdAt: date,
            reason: reason,
            worldSeed: manifest.world.worldSeed,
            playerPosition: manifest.player.position,
            manifestPath: manifest.files.manifestPath,
            regionDeltaPaths: regionDeltaPaths,
            blobHashes: blobHashes,
            summary: summary
        )

        return SnapshotStore(slotID: slotID, snapshots: snapshots + [snapshot])
    }

    public func retained(policy: SnapshotRetentionPolicy = SnapshotRetentionPolicy()) -> SnapshotStore {
        SnapshotStore(
            slotID: slotID,
            snapshots: retain(.manual, limit: policy.manualLimit) +
                retain(.autosave, limit: policy.autosaveLimit) +
                retain(.checkpoint, limit: policy.checkpointLimit) +
                snapshots.filter { $0.reason == .toolRevision } +
                (policy.keepPreMigration ? snapshots.filter { $0.reason == .preMigration } : [])
        )
    }

    private func retain(_ reason: SnapshotReason, limit: Int) -> [SaveSnapshotManifest] {
        Array(snapshots.filter { $0.reason == reason }.suffix(limit))
    }
}
