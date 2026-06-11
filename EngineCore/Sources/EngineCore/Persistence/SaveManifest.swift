import Foundation

public struct SaveSlotID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "SaveSlotID cannot be empty.")
        precondition(!rawValue.contains("/"), "SaveSlotID cannot contain path separators.")
        precondition(!rawValue.contains(".."), "SaveSlotID cannot contain parent path components.")

        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.init(rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String {
        rawValue
    }
}

public struct SaveSlotSummary: Hashable, Codable, Sendable {
    public let slotID: SaveSlotID
    public let displayName: String
    public let worldSeedText: String
    public let worldName: String
    public let lastSavedAt: Date
    public let playTimeSeconds: Double
    public let engineVersion: EngineVersion
    public let saveVersion: SaveVersion
    public let playerRegion: RegionCoordinate
    public let worldDescription: String

    public init(
        slotID: SaveSlotID,
        displayName: String,
        worldSeedText: String,
        worldName: String,
        lastSavedAt: Date,
        playTimeSeconds: Double,
        engineVersion: EngineVersion,
        saveVersion: SaveVersion,
        playerRegion: RegionCoordinate,
        worldDescription: String
    ) {
        self.slotID = slotID
        self.displayName = displayName
        self.worldSeedText = worldSeedText
        self.worldName = worldName
        self.lastSavedAt = lastSavedAt
        self.playTimeSeconds = playTimeSeconds
        self.engineVersion = engineVersion
        self.saveVersion = saveVersion
        self.playerRegion = playerRegion
        self.worldDescription = worldDescription
    }
}

public struct SaveManifest: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldSavePackage"

    public let format: String
    public let slotID: SaveSlotID
    public let displayName: String
    public let worldName: String
    public let worldDescription: String
    public let createdAt: Date
    public let lastSavedAt: Date
    public let playTimeSeconds: Double
    public let engineVersion: EngineVersion
    public let saveVersion: SaveVersion
    public let world: SaveWorldManifest
    public let player: SavePlayerState
    public let files: SaveFilesManifest
    public let integrity: SaveIntegrityManifest

    public init(
        format: String = Self.currentFormat,
        slotID: SaveSlotID,
        displayName: String,
        worldName: String,
        worldDescription: String = "",
        createdAt: Date,
        lastSavedAt: Date,
        playTimeSeconds: Double = 0,
        engineVersion: EngineVersion = .current,
        saveVersion: SaveVersion = .current,
        world: SaveWorldManifest,
        player: SavePlayerState,
        files: SaveFilesManifest = SaveFilesManifest(),
        integrity: SaveIntegrityManifest = SaveIntegrityManifest()
    ) {
        precondition(!displayName.isEmpty, "displayName cannot be empty.")
        precondition(!worldName.isEmpty, "worldName cannot be empty.")
        precondition(playTimeSeconds >= 0, "playTimeSeconds must be non-negative.")

        self.format = format
        self.slotID = slotID
        self.displayName = displayName
        self.worldName = worldName
        self.worldDescription = worldDescription
        self.createdAt = createdAt
        self.lastSavedAt = lastSavedAt
        self.playTimeSeconds = playTimeSeconds
        self.engineVersion = engineVersion
        self.saveVersion = saveVersion
        self.world = world
        self.player = player
        self.files = files
        self.integrity = integrity
    }

    public static func newWorld(
        slotID: SaveSlotID,
        displayName: String,
        worldName: String,
        seedText: String,
        worldSeed: WorldSeed,
        playerProfile: PlayerProfile = PlayerProfile(),
        playerPosition: WorldPosition = WorldPosition(x: 0, y: 0, z: 0),
        generatorVersions: GeneratorVersionTable = .current,
        createdAt: Date = Date()
    ) -> SaveManifest {
        SaveManifest(
            slotID: slotID,
            displayName: displayName,
            worldName: worldName,
            createdAt: createdAt,
            lastSavedAt: createdAt,
            world: SaveWorldManifest(
                seedText: seedText,
                worldSeed: worldSeed,
                worldDNA: WorldDNA.make(
                    worldSeed: worldSeed,
                    generatorVersions: generatorVersions
                ),
                generatorVersions: generatorVersions
            ),
            player: SavePlayerState(
                profile: playerProfile
                    .recordingRecentSeed(seedText)
                    .opening(slotID: slotID),
                position: playerPosition
            )
        )
    }

    public var summary: SaveSlotSummary {
        SaveSlotSummary(
            slotID: slotID,
            displayName: displayName,
            worldSeedText: world.seedText,
            worldName: worldName,
            lastSavedAt: lastSavedAt,
            playTimeSeconds: playTimeSeconds,
            engineVersion: engineVersion,
            saveVersion: saveVersion,
            playerRegion: player.region,
            worldDescription: worldDescription
        )
    }

    public func saved(
        at date: Date,
        playTimeSeconds: Double,
        player: SavePlayerState,
        generation: Int? = nil
    ) -> SaveManifest {
        SaveManifest(
            format: format,
            slotID: slotID,
            displayName: displayName,
            worldName: worldName,
            worldDescription: worldDescription,
            createdAt: createdAt,
            lastSavedAt: date,
            playTimeSeconds: playTimeSeconds,
            engineVersion: engineVersion,
            saveVersion: saveVersion,
            world: world,
            player: player,
            files: files,
            integrity: integrity.advanced(to: generation ?? integrity.generation + 1)
        )
    }
}

public struct SaveWorldManifest: Hashable, Codable, Sendable {
    public let seedText: String
    public let worldSeed: WorldSeed
    public let worldDNA: WorldDNA
    public let generatorVersions: GeneratorVersionTable

    public init(
        seedText: String,
        worldSeed: WorldSeed,
        worldDNA: WorldDNA,
        generatorVersions: GeneratorVersionTable
    ) {
        precondition(!seedText.isEmpty, "seedText cannot be empty.")

        self.seedText = seedText
        self.worldSeed = worldSeed
        self.worldDNA = worldDNA
        self.generatorVersions = generatorVersions
    }
}

public struct SavePlayerState: Hashable, Codable, Sendable {
    public let profile: PlayerProfile
    public let position: WorldPosition
    public let region: RegionCoordinate
    public let cameraYaw: Float
    public let cameraPitch: Float

    public init(
        profile: PlayerProfile,
        position: WorldPosition,
        region: RegionCoordinate? = nil,
        cameraYaw: Float = 0,
        cameraPitch: Float = 0
    ) {
        self.profile = profile
        self.position = position
        self.region = region ?? RegionCoordinate.containing(
            ChunkCoordinate.containing(position, chunkSize: 16),
            regionSizeInChunks: 8
        )
        self.cameraYaw = cameraYaw
        self.cameraPitch = cameraPitch
    }
}

public struct SaveFilesManifest: Hashable, Codable, Sendable {
    public let manifestPath: String
    public let modifiedRegionsPath: String?
    public let blobsPath: String?
    public let snapshotsPath: String?

    public init(
        manifestPath: String = "manifest.json",
        modifiedRegionsPath: String? = nil,
        blobsPath: String? = nil,
        snapshotsPath: String? = nil
    ) {
        precondition(!manifestPath.isEmpty, "manifestPath cannot be empty.")

        self.manifestPath = manifestPath
        self.modifiedRegionsPath = modifiedRegionsPath
        self.blobsPath = blobsPath
        self.snapshotsPath = snapshotsPath
    }
}

public struct SaveIntegrityManifest: Hashable, Codable, Sendable {
    public let generation: Int
    public let manifestChecksum: String?

    public init(generation: Int = 0, manifestChecksum: String? = nil) {
        precondition(generation >= 0, "generation must be non-negative.")

        self.generation = generation
        self.manifestChecksum = manifestChecksum
    }

    public func advanced(to generation: Int) -> SaveIntegrityManifest {
        SaveIntegrityManifest(
            generation: generation,
            manifestChecksum: manifestChecksum
        )
    }
}
