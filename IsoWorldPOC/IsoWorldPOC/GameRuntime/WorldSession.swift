import Foundation
import EngineCore

struct WorldSessionID: Hashable, Identifiable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct WorldSession: Identifiable {
    let id: WorldSessionID
    let seed: String
    let worldSeed: WorldSeed
    let dna: WorldDNA
    let spawnPosition: WorldPosition
    let initialChunkRadius: Int
    let initialChunks: [ProceduralChunkData]
    let openRequirements: WorldOpenRequirements

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
        openRequirements: WorldOpenRequirements
    ) {
        self.id = id
        self.seed = seed
        self.worldSeed = worldSeed
        self.dna = dna
        self.spawnPosition = spawnPosition
        self.initialChunkRadius = initialChunkRadius
        self.initialChunks = initialChunks
        self.openRequirements = openRequirements
    }
}
