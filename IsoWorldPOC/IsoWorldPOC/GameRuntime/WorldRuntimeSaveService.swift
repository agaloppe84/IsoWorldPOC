import Combine
import EngineCore
import Foundation

@MainActor
final class WorldRuntimeHandle: ObservableObject {
    fileprivate(set) var runtime: WorldRuntime?

    func attach(runtime: WorldRuntime) {
        self.runtime = runtime
    }
}

struct WorldRuntimePersistenceCapture: Sendable {
    let seedText: String
    let worldSeed: WorldSeed
    let worldDNA: WorldDNA
    let playerState: SavePlayerState
    let playerEntityID: StableID
    let currentChunk: ChunkCoordinate
    let activeChunkCoordinates: [ChunkCoordinate]
    let visibleChunkCoordinates: [ChunkCoordinate]
    let frameIndex: UInt64
    let simulationTime: Float
    let dirtyTracker: DirtyTracker
    let regionDeltaStore: RegionDeltaStore
    let entityStore: EntityStateStore
}

struct WorldRuntimeSaveResult: Sendable {
    let saveRootURL: URL
    let coordinatorResult: SaveCoordinatorResult
    let inspection: SaveInspectionReport

    var manifest: SaveManifest {
        coordinatorResult.manifest
    }
}

struct WorldRuntimeLoadResult: Sendable {
    let saveRootURL: URL
    let manifest: SaveManifest
    let session: WorldSession
    let regionDeltaFiles: [RegionDeltaFile]
    let entityStore: EntityStateStore?
    let blobManifest: CASBlobManifest?
    let inspection: SaveInspectionReport
}

enum WorldRuntimeSaveServiceError: Error, Equatable, Sendable {
    case missingManifest(URL)
    case unrecoverableSave(SaveRecoveryStatus)
    case noInitialChunks(URL)
}

struct WorldRuntimeSaveService {
    private let fileWriter: AtomicFileWriter
    private let saveCoordinator: SaveCoordinator
    private let recoveryScanner: SaveRecoveryScanner
    private let saveInspector: SaveInspector
    private let regionFileStore: RegionDeltaFileStore
    private let entityStateFileStore: EntityStateFileStore
    private let blobStore: CASBlobStore

    init(
        fileWriter: AtomicFileWriter = AtomicFileWriter(),
        saveCoordinator: SaveCoordinator = SaveCoordinator(),
        recoveryScanner: SaveRecoveryScanner = SaveRecoveryScanner(),
        saveInspector: SaveInspector = SaveInspector(),
        regionFileStore: RegionDeltaFileStore = RegionDeltaFileStore(),
        entityStateFileStore: EntityStateFileStore = EntityStateFileStore(),
        blobStore: CASBlobStore = CASBlobStore()
    ) {
        self.fileWriter = fileWriter
        self.saveCoordinator = saveCoordinator
        self.recoveryScanner = recoveryScanner
        self.saveInspector = saveInspector
        self.regionFileStore = regionFileStore
        self.entityStateFileStore = entityStateFileStore
        self.blobStore = blobStore
    }

    @MainActor
    func save(
        runtime: WorldRuntime,
        to saveRootURL: URL,
        slotID: SaveSlotID,
        displayName: String,
        worldName: String,
        date: Date = Date()
    ) async throws -> WorldRuntimeSaveResult {
        let capture = runtime.makePersistenceCapture()
        let baseManifest = existingManifest(at: saveRootURL) ?? makeNewManifest(
            capture: capture,
            slotID: slotID,
            displayName: displayName,
            worldName: worldName,
            date: date
        )
        let journal = loadEventJournal(from: baseManifest, rootURL: saveRootURL)
        let snapshots = loadSnapshotStore(from: baseManifest, rootURL: saveRootURL)
        let blobManifest = try makeRuntimeBlobManifest(
            capture: capture,
            rootURL: saveRootURL
        )
        let request = SaveCoordinatorRequest(
            manifest: baseManifest,
            player: capture.playerState,
            playTimeSeconds: max(baseManifest.playTimeSeconds, Double(capture.simulationTime)),
            dirtyTracker: capture.dirtyTracker,
            regionDeltaStore: capture.regionDeltaStore,
            eventJournal: journal,
            snapshotStore: snapshots,
            entityStore: capture.entityStore,
            blobManifest: blobManifest,
            tick: capture.frameIndex,
            date: date,
            summary: "Runtime world save"
        )
        let result = try await saveCoordinator.save(request, to: saveRootURL)
        let inspection = saveInspector.inspect(rootURL: saveRootURL)

        return WorldRuntimeSaveResult(
            saveRootURL: saveRootURL,
            coordinatorResult: result,
            inspection: inspection
        )
    }

    @MainActor
    func load(from saveRootURL: URL) async throws -> WorldRuntimeLoadResult {
        let recovery = recoveryScanner.scan(rootURL: saveRootURL)

        switch recovery.status {
        case .clean:
            break
        case .needsRollback:
            _ = try recoveryScanner.rollbackUncommittedArtifacts(rootURL: saveRootURL)
        case .missingManifest:
            throw WorldRuntimeSaveServiceError.missingManifest(saveRootURL)
        case .corrupt:
            throw WorldRuntimeSaveServiceError.unrecoverableSave(recovery.status)
        }

        let manifestURL = saveRootURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw WorldRuntimeSaveServiceError.missingManifest(saveRootURL)
        }

        let manifest = try fileWriter.readJSON(SaveManifest.self, from: manifestURL)
        let snapshotStore = loadSnapshotStore(from: manifest, rootURL: saveRootURL)
        let regionFiles = loadRegionDeltaFiles(
            manifest: manifest,
            snapshotStore: snapshotStore,
            rootURL: saveRootURL
        )
        let entityPackage = try? entityStateFileStore.read(
            relativeTo: saveRootURL,
            relativePath: manifest.files.entityStatePath ?? EntityStateFileStore.defaultRelativePath,
            expectedWorldSeed: manifest.world.worldSeed
        )
        let blobManifest = try? blobStore.readManifest(relativeTo: saveRootURL)
        let initialChunks = try makeInitialChunks(
            manifest: manifest,
            regionDeltaFiles: regionFiles,
            entityStore: entityPackage?.store
        )
        let requirements = WorldOpenRequirements(
            normalizedSeed: manifest.world.seedText,
            worldSeed: manifest.world.worldSeed,
            initialChunkRadius: 0,
            requiredInitialChunkCount: initialChunks.count,
            preparedChunkCount: initialChunks.count,
            missingInitialChunks: [],
            spawnPosition: manifest.player.position,
            hasWorldDNA: true,
            hasWorldRules: true,
            hasRenderPayloads: !initialChunks.isEmpty,
            hasCollisionBootstrap: !initialChunks.isEmpty,
            hasRendererWarmupPayload: !initialChunks.isEmpty
        )
        guard !initialChunks.isEmpty else {
            throw WorldRuntimeSaveServiceError.noInitialChunks(saveRootURL)
        }
        let session = WorldSession(
            seed: manifest.world.seedText,
            worldSeed: manifest.world.worldSeed,
            dna: manifest.world.worldDNA,
            spawnPosition: manifest.player.position,
            initialChunkRadius: 0,
            initialChunks: initialChunks,
            openRequirements: requirements,
            saveRootURL: saveRootURL,
            saveManifest: manifest,
            loadedRegionDeltaFiles: regionFiles,
            loadedEntityStore: entityPackage?.store,
            loadedBlobManifest: blobManifest
        )

        return WorldRuntimeLoadResult(
            saveRootURL: saveRootURL,
            manifest: manifest,
            session: session,
            regionDeltaFiles: regionFiles,
            entityStore: entityPackage?.store,
            blobManifest: blobManifest,
            inspection: saveInspector.inspect(rootURL: saveRootURL)
        )
    }

    private func existingManifest(at saveRootURL: URL) -> SaveManifest? {
        try? fileWriter.readJSON(
            SaveManifest.self,
            from: saveRootURL.appendingPathComponent("manifest.json")
        )
    }

    private func makeNewManifest(
        capture: WorldRuntimePersistenceCapture,
        slotID: SaveSlotID,
        displayName: String,
        worldName: String,
        date: Date
    ) -> SaveManifest {
        SaveManifest(
            slotID: slotID,
            displayName: displayName,
            worldName: worldName,
            createdAt: date,
            lastSavedAt: date,
            playTimeSeconds: Double(capture.simulationTime),
            world: SaveWorldManifest(
                seedText: capture.seedText,
                worldSeed: capture.worldSeed,
                worldDNA: capture.worldDNA,
                generatorVersions: .current
            ),
            player: capture.playerState
        )
    }

    private func loadEventJournal(
        from manifest: SaveManifest,
        rootURL: URL
    ) -> EventJournal {
        guard let path = manifest.files.eventJournalPath else {
            return EventJournal(slotID: manifest.slotID)
        }

        return (try? fileWriter.readJSON(
            EventJournal.self,
            from: rootURL.appendingPathComponent(path)
        )) ?? EventJournal(slotID: manifest.slotID)
    }

    private func loadSnapshotStore(
        from manifest: SaveManifest,
        rootURL: URL
    ) -> SnapshotStore {
        guard let path = manifest.files.snapshotIndexPath else {
            return SnapshotStore(slotID: manifest.slotID)
        }

        return (try? fileWriter.readJSON(
            SnapshotStore.self,
            from: rootURL.appendingPathComponent(path)
        )) ?? SnapshotStore(slotID: manifest.slotID)
    }

    private func makeRuntimeBlobManifest(
        capture: WorldRuntimePersistenceCapture,
        rootURL: URL
    ) throws -> CASBlobManifest {
        let payload = WorldRuntimeCASPayload(
            seedText: capture.seedText,
            worldSeed: capture.worldSeed,
            playerEntityID: capture.playerEntityID,
            playerPosition: capture.playerState.position,
            currentChunk: capture.currentChunk,
            activeChunkCoordinates: capture.activeChunkCoordinates,
            visibleChunkCoordinates: capture.visibleChunkCoordinates,
            frameIndex: capture.frameIndex,
            simulationTime: capture.simulationTime,
            entityCount: capture.entityStore.entities.count
        )
        let data = try AtomicFileWriter.makeJSONEncoder().encode(payload)
        let blob = try blobStore.write(data, kind: .runtimeAsset, relativeTo: rootURL)
        return CASBlobManifest(blobs: [blob])
    }

    private func loadRegionDeltaFiles(
        manifest: SaveManifest,
        snapshotStore: SnapshotStore,
        rootURL: URL
    ) -> [RegionDeltaFile] {
        let latestPaths = snapshotStore.snapshots.last?.regionDeltaPaths ?? []
        let paths = latestPaths.isEmpty ? enumerateRegionDeltaPaths(rootURL: rootURL) : latestPaths

        return paths.compactMap { path in
            try? regionFileStore.read(
                from: rootURL.appendingPathComponent(path),
                expectedWorldSeed: manifest.world.worldSeed
            )
        }
        .sorted { first, second in
            isCoordinate(first.region, orderedBefore: second.region)
        }
    }

    private func enumerateRegionDeltaPaths(rootURL: URL) -> [String] {
        let regionsURL = rootURL.appendingPathComponent("regions", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: regionsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> String? in
            guard let url = item as? URL, url.lastPathComponent.hasSuffix(".isoregion") else {
                return nil
            }

            return "regions/\(url.lastPathComponent)"
        }
        .sorted()
    }

    private func makeInitialChunks(
        manifest: SaveManifest,
        regionDeltaFiles: [RegionDeltaFile],
        entityStore: EntityStateStore?
    ) throws -> [ProceduralChunkData] {
        let coordinates = initialChunkCoordinates(
            manifest: manifest,
            regionDeltaFiles: regionDeltaFiles,
            entityStore: entityStore
        )

        return coordinates.map { coordinate in
            ProceduralChunkDataFactory.makeChunkData(
                coordinate: coordinate,
                worldSeed: manifest.world.worldSeed
            )
        }
    }

    private func initialChunkCoordinates(
        manifest: SaveManifest,
        regionDeltaFiles: [RegionDeltaFile],
        entityStore: EntityStateStore?
    ) -> [ChunkCoordinate] {
        var coordinates = Set<ChunkCoordinate>()
        coordinates.insert(chunkCoordinate(containing: manifest.player.position))

        for file in regionDeltaFiles {
            for chunk in file.chunks {
                coordinates.insert(chunk.coordinate)
            }
        }

        for entity in entityStore?.entities ?? [] where !entity.isRemoved {
            coordinates.insert(entity.chunk)
        }

        return coordinates.sorted { first, second in
            isCoordinate(first, orderedBefore: second)
        }
    }

    private func chunkCoordinate(containing position: WorldPosition) -> ChunkCoordinate {
        let halfChunkSize = ProceduralChunkDataFactory.chunkWorldSize * 0.5

        return ChunkCoordinate(
            x: Int(((position.x + halfChunkSize) / ProceduralChunkDataFactory.chunkWorldSize).rounded(.down)),
            y: 0,
            z: Int(((position.z + halfChunkSize) / ProceduralChunkDataFactory.chunkWorldSize).rounded(.down))
        )
    }

    private func isCoordinate(
        _ first: ChunkCoordinate,
        orderedBefore second: ChunkCoordinate
    ) -> Bool {
        if first.z != second.z {
            return first.z < second.z
        }

        if first.x != second.x {
            return first.x < second.x
        }

        return first.y < second.y
    }

    private func isCoordinate(
        _ first: RegionCoordinate,
        orderedBefore second: RegionCoordinate
    ) -> Bool {
        if first.z != second.z {
            return first.z < second.z
        }

        if first.x != second.x {
            return first.x < second.x
        }

        return first.y < second.y
    }
}

private struct WorldRuntimeCASPayload: Codable, Sendable {
    let seedText: String
    let worldSeed: WorldSeed
    let playerEntityID: StableID
    let playerPosition: WorldPosition
    let currentChunk: ChunkCoordinate
    let activeChunkCoordinates: [ChunkCoordinate]
    let visibleChunkCoordinates: [ChunkCoordinate]
    let frameIndex: UInt64
    let simulationTime: Float
    let entityCount: Int
}
