import Foundation
import EngineCore

struct WorldSessionID: Hashable, Identifiable, Sendable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct WorldSession: Identifiable, Sendable {
    let id: WorldSessionID
    let seed: String
    let worldSeed: WorldSeed
    let dna: WorldDNA
    let spawnPosition: WorldPosition
    let initialChunkRadius: Int
    let initialChunks: [ProceduralChunkData]
    let openRequirements: WorldOpenRequirements
    let saveRootURL: URL?
    let saveManifest: SaveManifest?
    let loadedRegionDeltaFiles: [RegionDeltaFile]
    let loadedEntityStore: EntityStateStore?
    let loadedBlobManifest: CASBlobManifest?

    var initialChunkCount: Int {
        initialChunks.count
    }

    init(
        id: WorldSessionID = WorldSessionID(),
        seed: String,
        worldSeed: WorldSeed,
        dna: WorldDNA,
        spawnPosition: WorldPosition,
        initialChunkRadius: Int,
        initialChunks: [ProceduralChunkData],
        openRequirements: WorldOpenRequirements,
        saveRootURL: URL? = nil,
        saveManifest: SaveManifest? = nil,
        loadedRegionDeltaFiles: [RegionDeltaFile] = [],
        loadedEntityStore: EntityStateStore? = nil,
        loadedBlobManifest: CASBlobManifest? = nil
    ) {
        self.id = id
        self.seed = seed
        self.worldSeed = worldSeed
        self.dna = dna
        self.spawnPosition = spawnPosition
        self.initialChunkRadius = initialChunkRadius
        self.initialChunks = initialChunks
        self.openRequirements = openRequirements
        self.saveRootURL = saveRootURL
        self.saveManifest = saveManifest
        self.loadedRegionDeltaFiles = loadedRegionDeltaFiles
        self.loadedEntityStore = loadedEntityStore
        self.loadedBlobManifest = loadedBlobManifest
    }
}
