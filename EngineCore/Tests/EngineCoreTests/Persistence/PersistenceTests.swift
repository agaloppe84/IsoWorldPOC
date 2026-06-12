import Foundation
import XCTest
@testable import EngineCore

final class PersistenceTests: XCTestCase {
    func testSaveManifestRoundTripsThroughReadableJSON() throws {
        let manifest = makeManifest(slotID: "slot-roundtrip", seedText: "roundtrip-seed")
        let data = try AtomicFileWriter.makeJSONEncoder().encode(manifest)
        let decoded = try AtomicFileWriter.makeJSONDecoder().decode(SaveManifest.self, from: data)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertEqual(decoded, manifest)
        XCTAssertTrue(json.contains("\"format\" : \"IsoWorldSavePackage\""))
        XCTAssertEqual(decoded.world.worldDNA, WorldDNA.make(worldSeed: manifest.world.worldSeed))
        XCTAssertEqual(decoded.world.generatorVersions, .current)
    }

    func testSaveManifestDefaultFilesDoNotPersistGeneratedCaches() {
        let manifest = makeManifest(slotID: "slot-no-cache", seedText: "cache-test")

        XCTAssertEqual(manifest.files.manifestPath, "manifest.json")
        XCTAssertNil(manifest.files.modifiedRegionsPath)
        XCTAssertNil(manifest.files.blobsPath)
        XCTAssertNil(manifest.files.snapshotsPath)
        XCTAssertNil(manifest.files.eventJournalPath)
        XCTAssertNil(manifest.files.entityStatePath)
        XCTAssertNil(manifest.files.sqliteIndexPath)
    }

    func testPersistenceRegistryDeclaresV2AuthoritativeAndRebuildableDomains() {
        let registry = PersistenceRegistry.productionV2

        XCTAssertEqual(registry.rootPath(for: .manifest), "manifest.json")
        XCTAssertEqual(registry.rootPath(for: .regionDeltas), "regions")
        XCTAssertEqual(registry.rootPath(for: .eventJournal), "events/journal.json")
        XCTAssertEqual(registry.rootPath(for: .entityState), "entities/state.isoentity")
        XCTAssertEqual(
            registry.descriptor(for: .regionDeltas)?.fileExtension,
            "isoregion"
        )
        XCTAssertTrue(registry.authoritativeDomains.contains(.manifest))
        XCTAssertTrue(registry.authoritativeDomains.contains(.regionDeltas))
        XCTAssertTrue(registry.authoritativeDomains.contains(.blobStore))
        XCTAssertTrue(registry.rebuildableDomains.contains(.sqliteIndex))
        XCTAssertTrue(registry.rebuildableDomains.contains(.generatedCaches))
        XCTAssertFalse(registry.authoritativeDomains.contains(.sqliteIndex))
    }

    func testPlayerProfileRecordsRecentSeedsWithDeduplication() {
        let profile = PlayerProfile(displayName: "Tester")
            .recordingRecentSeed("alpha")
            .recordingRecentSeed("beta")
            .recordingRecentSeed("alpha")
            .recordingRecentSeed("  gamma  ")

        XCTAssertEqual(profile.recentSeeds, ["gamma", "alpha", "beta"])
    }

    func testAtomicFileWriterReplacesExistingFileAndRemovesTemporaryFiles() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("manifest.json")
        let writer = AtomicFileWriter()
        try writer.write(Data("first".utf8), to: url)
        try writer.write(Data("second".utf8), to: url)

        let contents = try String(contentsOf: url, encoding: .utf8)
        let leftoverTemporaryFiles = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasSuffix(".tmp") }

        XCTAssertEqual(contents, "second")
        XCTAssertTrue(leftoverTemporaryFiles.isEmpty)
    }

    func testSaveSlotManagerWritesLoadsListsAndDeletesManifest() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = SaveSlotManager(rootDirectory: directory)
        let first = makeManifest(
            slotID: "slot-first",
            seedText: "first-seed",
            date: Date(timeIntervalSince1970: 200)
        )
        let second = makeManifest(
            slotID: "slot-second",
            seedText: "second-seed",
            date: Date(timeIntervalSince1970: 100)
        )

        try await manager.save(first)
        try await manager.save(second)

        let loaded = try await manager.load(slotID: first.slotID)
        let summaries = try await manager.listSlots()

        XCTAssertEqual(loaded, first)
        XCTAssertEqual(summaries.map(\.slotID), [first.slotID, second.slotID])
        XCTAssertEqual(summaries.first?.worldSeedText, "first-seed")

        try await manager.delete(slotID: first.slotID)
        let remaining = try await manager.listSlots()

        XCTAssertEqual(remaining.map(\.slotID), [second.slotID])
    }

    func testSaveManifestSavedAdvancesGenerationAndKeepsStableWorldInputs() {
        let manifest = makeManifest(slotID: "slot-save", seedText: "save-seed")
        let updatedPlayer = SavePlayerState(
            profile: manifest.player.profile,
            position: WorldPosition(x: 4, y: 5, z: -6),
            cameraYaw: 0.75,
            cameraPitch: -0.2
        )
        let saved = manifest.saved(
            at: Date(timeIntervalSince1970: 400),
            playTimeSeconds: 42,
            player: updatedPlayer
        )

        XCTAssertEqual(saved.integrity.generation, manifest.integrity.generation + 1)
        XCTAssertEqual(saved.playTimeSeconds, 42)
        XCTAssertEqual(saved.player.position, updatedPlayer.position)
        XCTAssertEqual(saved.world, manifest.world)
        XCTAssertEqual(saved.createdAt, manifest.createdAt)
    }

    func testGeneratorVersionTablePersistenceHashChangesWithVersions() {
        let current = GeneratorVersionTable.persistenceCurrent
        let changed = current.setting(GeneratorVersion(major: 2), for: .terrain)

        XCTAssertEqual(current.persistenceHash, GeneratorVersionTable.current.persistenceHash)
        XCTAssertNotEqual(current.persistenceHash, changed.persistenceHash)
    }

    func testDirtyTrackerGroupsChunksByRegionAndMarksSavedTicks() throws {
        let chunkA = ChunkCoordinate(x: 5, y: 0, z: -1)
        let chunkB = ChunkCoordinate(x: -1, y: 0, z: 0)
        let tracker = DirtyTracker(regionSizeInChunks: 4)
            .markingDirty(
                coordinate: chunkA,
                tick: 10,
                systemID: "terrain",
                reason: .terrainDelta
            )
            .markingDirty(
                coordinate: chunkA,
                tick: 12,
                systemID: "props",
                reason: .propDelta
            )
            .markingDirty(
                coordinate: chunkB,
                tick: 11,
                systemID: "entities",
                reason: .entityState
            )

        let scope = tracker.dirtyScope()
        let recordA = try XCTUnwrap(scope.records.first { $0.coordinate == chunkA })
        let saved = tracker.markSaved(upTo: 11)

        XCTAssertEqual(scope.records.count, 2)
        XCTAssertEqual(recordA.firstDirtyTick, 10)
        XCTAssertEqual(recordA.lastDirtyTick, 12)
        XCTAssertEqual(recordA.systemIDs, ["props", "terrain"])
        XCTAssertEqual(recordA.reasons, [DirtyReason.terrainDelta, .propDelta])
        XCTAssertEqual(Set(scope.dirtyRegions), [
            RegionCoordinate.containing(chunkA, regionSizeInChunks: 4),
            RegionCoordinate.containing(chunkB, regionSizeInChunks: 4)
        ])
        XCTAssertEqual(saved.lastSavedTick, 11)
        XCTAssertEqual(saved.dirtyScope().records.map { $0.coordinate }, [chunkA])
    }

    func testDirtyTrackerCanMarkOnlyASavedScope() {
        let chunkA = ChunkCoordinate(x: 0, y: 0, z: 0)
        let chunkB = ChunkCoordinate(x: 1, y: 0, z: 0)
        let tracker = DirtyTracker(regionSizeInChunks: 1)
            .markingDirty(
                coordinate: chunkA,
                tick: 10,
                systemID: "terrain",
                reason: .terrainDelta
            )
            .markingDirty(
                coordinate: chunkB,
                tick: 9,
                systemID: "props",
                reason: .propDelta
            )
        let savedScope = DirtyScope(records: tracker.dirtyScope().records.filter { $0.coordinate == chunkA })
        let saved = tracker.markSaved(savedScope)

        XCTAssertEqual(saved.lastSavedTick, 0)
        XCTAssertEqual(saved.dirtyScope(since: nil).records.map(\.coordinate), [chunkB])
    }

    func testRegionDeltaStoreMergesChunkDeltasIntoStableRegionFiles() throws {
        let worldSeed = WorldSeed(99)
        let chunk = ChunkCoordinate(x: 9, y: 0, z: -1)
        let propID = StableID(1001)
        let store = RegionDeltaStore(worldSeed: worldSeed, regionSizeInChunks: 4)
            .adding(
                ChunkDelta(
                    coordinate: chunk,
                    terrainDeltas: [TerrainSampleDelta(localX: 2, localZ: 3, heightOffset: 0.25)],
                    lastModifiedTick: 10
                )
            )
            .adding(
                ChunkDelta(
                    coordinate: chunk,
                    propDeltas: [PropDelta(propID: propID, action: .placed, type: .tree)],
                    lastModifiedTick: 12
                )
            )

        let region = RegionCoordinate.containing(chunk, regionSizeInChunks: 4)
        let file = try XCTUnwrap(store.file(for: region))
        let mergedChunk = try XCTUnwrap(file.chunks.first)

        XCTAssertEqual(store.files.count, 1)
        XCTAssertEqual(file.relativePath, "regions/r.2.0.-1.isoregion")
        XCTAssertEqual(file.generatorVersionsHash, GeneratorVersionTable.current.persistenceHash)
        XCTAssertEqual(mergedChunk.terrainDeltas.count, 1)
        XCTAssertEqual(mergedChunk.propDeltas.count, 1)
        XCTAssertEqual(mergedChunk.lastModifiedTick, 12)
        XCTAssertEqual(store.relativePaths, [file.relativePath])
    }

    func testRegionDeltaFileStoreWritesAndReadsIsoRegionFiles() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let worldSeed = WorldSeed(99)
        let region = RegionCoordinate(x: 2, y: 0, z: -1)
        let file = RegionDeltaFile(
            worldSeed: worldSeed,
            region: region,
            generation: 3,
            generatorVersionsHash: GeneratorVersionTable.current.persistenceHash,
            chunks: [
                ChunkDelta(
                    coordinate: ChunkCoordinate(x: 9, y: 0, z: -1),
                    terrainDeltas: [TerrainSampleDelta(localX: 2, localZ: 3, heightOffset: 0.25)],
                    lastModifiedTick: 10
                )
            ]
        )
        let store = RegionDeltaFileStore()
        let path = try store.write(file, relativeTo: directory)
        let loaded = try store.read(
            region: region,
            relativeTo: directory,
            expectedWorldSeed: worldSeed
        )

        XCTAssertEqual(path, "regions/r.2.0.-1.isoregion")
        XCTAssertEqual(loaded, file)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(path).path))
    }

    func testSaveCoordinatorManualSavePersistsManifestRegionsJournalAndSnapshots() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifest = makeManifest(slotID: "coordinator-manual", seedText: "manual-seed")
        let chunk = ChunkCoordinate(x: 1, y: 0, z: 1)
        let tracker = DirtyTracker(regionSizeInChunks: 4)
            .markingDirty(
                coordinate: chunk,
                tick: 10,
                systemID: "terrain",
                reason: .terrainDelta
            )
        let regionStore = RegionDeltaStore(
            worldSeed: manifest.world.worldSeed,
            regionSizeInChunks: 4
        )
        .adding(
            ChunkDelta(
                coordinate: chunk,
                terrainDeltas: [TerrainSampleDelta(localX: 1, localZ: 2, heightOffset: 0.5)],
                lastModifiedTick: 10
            )
        )
        let entityStore = EntityStateStore(regionSizeInChunks: 4).upserting(
            EntityPersistenceState(
                id: StableID(99),
                kind: .player,
                worldPosition: manifest.player.position,
                chunk: chunk,
                region: RegionCoordinate(x: 0, y: 0, z: 0),
                regionSizeInChunks: 4,
                lastModifiedTick: 10
            )
        )
        let request = SaveCoordinatorRequest(
            manifest: manifest,
            player: manifest.player,
            playTimeSeconds: 12,
            dirtyTracker: tracker,
            regionDeltaStore: regionStore,
            eventJournal: EventJournal(slotID: manifest.slotID),
            snapshotStore: SnapshotStore(slotID: manifest.slotID),
            entityStore: entityStore,
            tick: 10,
            date: Date(timeIntervalSince1970: 500),
            summary: "Manual save"
        )
        let result = try await SaveCoordinator().save(request, to: directory)
        let writer = AtomicFileWriter()
        let loadedManifest = try writer.readJSON(
            SaveManifest.self,
            from: directory.appendingPathComponent(result.manifestPath)
        )
        let loadedJournal = try writer.readJSON(
            EventJournal.self,
            from: directory.appendingPathComponent(result.eventJournalPath)
        )
        let loadedSnapshots = try writer.readJSON(
            SnapshotStore.self,
            from: directory.appendingPathComponent(try XCTUnwrap(result.snapshotIndexPath))
        )
        let loadedEntityPackage = try EntityStateFileStore().read(
            relativeTo: directory,
            relativePath: try XCTUnwrap(result.entityStatePath),
            expectedWorldSeed: manifest.world.worldSeed
        )
        let loadedRegion = try RegionDeltaFileStore().read(
            region: RegionCoordinate(x: 0, y: 0, z: 0),
            relativeTo: directory,
            expectedWorldSeed: manifest.world.worldSeed
        )

        XCTAssertEqual(result.generation, 1)
        XCTAssertEqual(result.writtenRegionPaths, ["regions/r.0.0.0.isoregion"])
        XCTAssertTrue(result.dirtyTracker.dirtyScope().isEmpty)
        XCTAssertEqual(loadedManifest.integrity.generation, 1)
        XCTAssertEqual(loadedManifest.files.modifiedRegionsPath, "regions")
        XCTAssertEqual(loadedManifest.files.eventJournalPath, "events/journal.json")
        XCTAssertEqual(loadedManifest.files.entityStatePath, "entities/state.isoentity")
        XCTAssertEqual(loadedManifest.files.sqliteIndexPath, "state.sqlite")
        XCTAssertEqual(result.entityStatePath, "entities/state.isoentity")
        XCTAssertEqual(result.sqliteIndexPath, "state.sqlite")
        XCTAssertEqual(loadedRegion.generation, 1)
        XCTAssertEqual(loadedEntityPackage.generation, 1)
        XCTAssertEqual(loadedEntityPackage.store.entities.map(\.id), [StableID(99)])
        XCTAssertEqual(loadedJournal.entries.map(\.kind), [.chunkDeltaWritten, .manualSaveCommitted])
        XCTAssertEqual(loadedSnapshots.snapshots.map(\.reason), [.manual])
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("entities/state.isoentity").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("state.sqlite").path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("snapshots/1.isosnapshot").path
            )
        )
    }

    func testSaveCoordinatorAutosaveDebouncesAndBudgetsRegions() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifest = makeManifest(slotID: "coordinator-auto", seedText: "auto-seed")
        let chunkA = ChunkCoordinate(x: 0, y: 0, z: 0)
        let chunkB = ChunkCoordinate(x: 1, y: 0, z: 0)
        let tracker = DirtyTracker(regionSizeInChunks: 1)
            .markingDirty(
                coordinate: chunkA,
                tick: 10,
                systemID: "terrain",
                reason: .terrainDelta
            )
            .markingDirty(
                coordinate: chunkB,
                tick: 11,
                systemID: "props",
                reason: .propDelta
            )
        let regionStore = RegionDeltaStore(
            worldSeed: manifest.world.worldSeed,
            regionSizeInChunks: 1
        )
        .adding(
            ChunkDelta(
                coordinate: chunkA,
                terrainDeltas: [TerrainSampleDelta(localX: 0, localZ: 0, heightOffset: 0.1)],
                lastModifiedTick: 10
            )
        )
        .adding(
            ChunkDelta(
                coordinate: chunkB,
                propDeltas: [PropDelta(propID: StableID(500), action: .placed, type: .rock)],
                lastModifiedTick: 11
            )
        )
        let coordinator = SaveCoordinator()
        let policy = AutosavePolicy(debounceSeconds: 60, maxRegionsPerPass: 1)
        let firstRequest = SaveCoordinatorRequest(
            manifest: manifest,
            player: manifest.player,
            playTimeSeconds: 20,
            dirtyTracker: tracker,
            regionDeltaStore: regionStore,
            eventJournal: EventJournal(slotID: manifest.slotID),
            snapshotStore: SnapshotStore(slotID: manifest.slotID),
            tick: 11,
            date: Date(timeIntervalSince1970: 100),
            summary: "Autosave"
        )
        let firstOptional = try await coordinator.autosave(firstRequest, policy: policy, to: directory)
        let first = try XCTUnwrap(firstOptional)
        let debouncedRequest = SaveCoordinatorRequest(
            manifest: first.manifest,
            player: first.manifest.player,
            playTimeSeconds: 25,
            dirtyTracker: first.dirtyTracker,
            regionDeltaStore: regionStore,
            eventJournal: first.eventJournal,
            snapshotStore: first.snapshotStore,
            tick: 12,
            date: Date(timeIntervalSince1970: 120),
            summary: "Autosave"
        )
        let debounced = try await coordinator.autosave(debouncedRequest, policy: policy, to: directory)
        let secondRequest = SaveCoordinatorRequest(
            manifest: first.manifest,
            player: first.manifest.player,
            playTimeSeconds: 30,
            dirtyTracker: first.dirtyTracker,
            regionDeltaStore: regionStore,
            eventJournal: first.eventJournal,
            snapshotStore: first.snapshotStore,
            tick: 13,
            date: Date(timeIntervalSince1970: 170),
            summary: "Autosave"
        )
        let secondOptional = try await coordinator.autosave(secondRequest, policy: policy, to: directory)
        let second = try XCTUnwrap(secondOptional)

        XCTAssertEqual(first.writtenRegionPaths, ["regions/r.0.0.0.isoregion"])
        XCTAssertEqual(first.dirtyTracker.dirtyScope().records.map(\.coordinate), [chunkB])
        XCTAssertEqual(first.eventJournal.entries.map(\.kind), [
            .autosaveStarted,
            .chunkDeltaWritten,
            .autosaveCommitted
        ])
        XCTAssertNil(debounced)
        XCTAssertEqual(second.writtenRegionPaths, ["regions/r.1.0.0.isoregion"])
        XCTAssertTrue(second.dirtyTracker.dirtyScope().isEmpty)
        XCTAssertEqual(second.manifest.integrity.generation, 2)
    }

    func testCASBlobStoreWritesVerifiesAndManifestsContentAddressedBlobs() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = CASBlobStore()
        let data = Data("blob-payload".utf8)
        let first = try store.write(data, kind: .toolExport, relativeTo: directory)
        let second = try store.write(data, kind: .toolExport, relativeTo: directory)
        let manifest = CASBlobManifest(blobs: [first])
        let manifestPath = try store.writeManifest(manifest, relativeTo: directory)
        let loadedManifest = try store.readManifest(relativeTo: directory)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.byteCount, data.count)
        XCTAssertEqual(first.relativePath, CASBlobStore.relativePath(for: first.hash))
        XCTAssertTrue(try store.verify(first, relativeTo: directory))
        XCTAssertEqual(manifestPath, "blobs/manifest.json")
        XCTAssertEqual(loadedManifest, manifest)
    }

    func testEntityStateFileStorePersistsAuthoritativeEntityState() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let worldSeed = WorldSeed(StableHash.make { builder in
            builder.combine("entity-state-file")
        }.value)
        let store = EntityStateStore().upserting(
            EntityPersistenceState(
                id: StableID.entity(worldSeed: worldSeed, localIndex: 0),
                kind: .player,
                worldPosition: WorldPosition(x: 2, y: 0, z: 3),
                lastModifiedTick: 12
            )
        )
        let fileStore = EntityStateFileStore()
        let path = try fileStore.write(
            store,
            worldSeed: worldSeed,
            generation: 2,
            relativeTo: directory
        )
        let loaded = try fileStore.read(
            relativeTo: directory,
            expectedWorldSeed: worldSeed
        )

        XCTAssertEqual(path, "entities/state.isoentity")
        XCTAssertEqual(loaded.generation, 2)
        XCTAssertEqual(loaded.store, store)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(path).path))
    }

    func testSQLiteStateIndexWritesWalBackedEntitiesEventsRegionsSnapshotsAndBlobs() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifest = makeManifest(slotID: "sqlite-index", seedText: "sqlite-seed")
        let regionFile = RegionDeltaFile(
            worldSeed: manifest.world.worldSeed,
            region: .origin,
            generation: 1,
            generatorVersionsHash: GeneratorVersionTable.current.persistenceHash,
            chunks: [
                ChunkDelta(
                    coordinate: .origin,
                    terrainDeltas: [TerrainSampleDelta(localX: 0, localZ: 0, heightOffset: 0.1)],
                    lastModifiedTick: 1
                )
            ]
        )
        let journal = EventJournal(slotID: manifest.slotID)
            .appending(
                kind: .manualSaveCommitted,
                tick: 1,
                date: Date(timeIntervalSince1970: 10),
                summary: "Manual save"
            )
        let savedManifest = manifest.saved(
            at: Date(timeIntervalSince1970: 10),
            playTimeSeconds: 3,
            player: manifest.player,
            generation: 1,
            files: .productionV2
        )
        let snapshots = SnapshotStore(slotID: manifest.slotID)
            .recording(
                manifest: savedManifest,
                reason: .manual,
                date: Date(timeIntervalSince1970: 10),
                regionDeltaPaths: [regionFile.relativePath],
                blobHashes: ["0xblob"],
                summary: "Manual save"
            )
        let entityStore = EntityStateStore().upserting(
            EntityPersistenceState(
                id: StableID(777),
                kind: .player,
                worldPosition: WorldPosition(x: 1, y: 2, z: 3),
                lastModifiedTick: 1
            )
        )
        let blob = CASBlobReference(
            hash: "0xblob",
            stableHash: StableHash(123),
            byteCount: 12,
            relativePath: "blobs/0xblob.blob",
            kind: .runtimeAsset
        )
        let summary = try SQLiteStateIndexStore().write(
            SQLiteStateIndexSnapshot(
                manifest: savedManifest,
                eventJournal: journal,
                snapshotStore: snapshots,
                regionFiles: [regionFile],
                entityStore: entityStore,
                blobManifest: CASBlobManifest(blobs: [blob])
            ),
            relativeTo: directory
        )
        let loaded = try SQLiteStateIndexStore().readSummary(relativeTo: directory)

        XCTAssertEqual(summary, loaded)
        XCTAssertTrue(summary.walEnabled)
        XCTAssertEqual(summary.userVersion, 2)
        XCTAssertEqual(summary.generation, 1)
        XCTAssertEqual(summary.entityCount, 1)
        XCTAssertEqual(summary.eventCount, 1)
        XCTAssertEqual(summary.regionFileCount, 1)
        XCTAssertEqual(summary.snapshotCount, 1)
        XCTAssertEqual(summary.blobCount, 1)
    }

    func testSaveInspectorDoesNotCreateSQLiteIndexForMissingSave() {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let report = SaveInspector().inspect(rootURL: directory)

        XCTAssertEqual(report.status, .missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("state.sqlite").path))
    }

    func testSaveCoordinatorCrashBeforeManifestLeavesRecoverableOrphans() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let manifest = makeManifest(slotID: "recovery", seedText: "recovery-seed")
        try AtomicFileWriter().writeJSON(manifest, to: directory.appendingPathComponent("manifest.json"))

        let chunk = ChunkCoordinate(x: 0, y: 0, z: 0)
        let tracker = DirtyTracker(regionSizeInChunks: 4)
            .markingDirty(
                coordinate: chunk,
                tick: 10,
                systemID: "terrain",
                reason: .terrainDelta
            )
        let regionStore = RegionDeltaStore(
            worldSeed: manifest.world.worldSeed,
            regionSizeInChunks: 4
        )
        .adding(
            ChunkDelta(
                coordinate: chunk,
                terrainDeltas: [TerrainSampleDelta(localX: 0, localZ: 0, heightOffset: 0.2)],
                lastModifiedTick: 10
            )
        )
        let request = SaveCoordinatorRequest(
            manifest: manifest,
            player: manifest.player,
            playTimeSeconds: 1,
            dirtyTracker: tracker,
            regionDeltaStore: regionStore,
            eventJournal: EventJournal(slotID: manifest.slotID),
            snapshotStore: SnapshotStore(slotID: manifest.slotID),
            tick: 10,
            date: Date(timeIntervalSince1970: 20),
            summary: "Injected crash",
            crashInjectionPoint: .beforeManifestCommit
        )

        do {
            _ = try await SaveCoordinator().save(request, to: directory)
            XCTFail("Expected injected crash before manifest commit.")
        } catch SaveCoordinatorError.injectedCrash(.beforeManifestCommit) {
            // Expected.
        }

        let scanner = SaveRecoveryScanner()
        let report = scanner.scan(rootURL: directory)
        let recovered = try scanner.rollbackUncommittedArtifacts(rootURL: directory)
        let committedManifest = try AtomicFileWriter().readJSON(
            SaveManifest.self,
            from: directory.appendingPathComponent("manifest.json")
        )

        XCTAssertEqual(report.status, .needsRollback)
        XCTAssertEqual(report.latestCommittedGeneration, 0)
        XCTAssertEqual(report.orphanRegionFileCount, 1)
        XCTAssertEqual(report.orphanSnapshotFileCount, 1)
        XCTAssertTrue(report.orphanRelativePaths.contains("state.sqlite"))
        XCTAssertTrue(report.orphanRelativePaths.contains("snapshots/index.json"))
        XCTAssertEqual(recovered.status, .clean)
        XCTAssertEqual(committedManifest.integrity.generation, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("state.sqlite").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("snapshots/index.json").path))
    }

    func testEntityStateStoreUpsertsRemovesAndExportsChunkDelta() throws {
        let entityID = StableID(2001)
        let position = WorldPosition(x: 127, y: 0, z: -1)
        let entity = EntityPersistenceState(
            id: entityID,
            kind: .settlementBuilding,
            displayName: "Workshop",
            worldPosition: position,
            stateVersion: 1,
            lastModifiedTick: 20,
            tags: [.settlement, .settlement],
            components: [
                EntityComponentState(
                    componentID: "build-progress",
                    schemaVersion: 1,
                    payloadHash: StableHash(42),
                    scalarValues: ["progress": 0.5]
                )
            ]
        )

        let store = EntityStateStore(regionSizeInChunks: 4)
            .upserting(entity)
            .removing(entityID: entityID, tick: 24)
        let removed = try XCTUnwrap(store.entity(id: entityID, includeRemoved: true))
        let chunkDelta = store.chunkDelta(for: removed.chunk, tick: 24)

        XCTAssertTrue(removed.isRemoved)
        XCTAssertEqual(removed.tags, [.settlement])
        XCTAssertEqual(store.entities(in: removed.region).count, 0)
        XCTAssertEqual(store.entities(in: removed.region, includeRemoved: true), [removed])
        XCTAssertEqual(chunkDelta.entityIDs, [entityID])
        XCTAssertEqual(chunkDelta.lastModifiedTick, 24)
    }

    func testEventJournalAppendsCompactsAndRoundTrips() throws {
        let journal = EventJournal(slotID: "journal-slot")
            .appending(
                kind: .worldCreated,
                tick: 1,
                date: Date(timeIntervalSince1970: 1),
                summary: "World created",
                tags: [.exploration]
            )
            .appending(
                kind: .chunkDeltaWritten,
                tick: 2,
                date: Date(timeIntervalSince1970: 2),
                summary: "Region written",
                relatedRegion: RegionCoordinate(x: 1, y: 0, z: -1)
            )

        let compacted = journal.compacted(keepingLast: 1)
        let data = try AtomicFileWriter.makeJSONEncoder().encode(journal)
        let decoded = try AtomicFileWriter.makeJSONDecoder().decode(EventJournal.self, from: data)

        XCTAssertEqual(journal.entries.map(\.sequence), [1, 2])
        XCTAssertEqual(journal.entries(since: 1).map(\.kind), [.chunkDeltaWritten])
        XCTAssertEqual(compacted.entries.map(\.sequence), [2])
        XCTAssertEqual(decoded, journal)
    }

    func testSnapshotStoreRecordsAndAppliesRetentionPolicy() {
        let manifest = makeManifest(slotID: "snapshots", seedText: "snapshot-seed")
        var store = SnapshotStore(slotID: manifest.slotID)

        for index in 0..<4 {
            store = store.recording(
                manifest: manifest.saved(
                    at: Date(timeIntervalSince1970: Double(index)),
                    playTimeSeconds: Double(index),
                    player: manifest.player,
                    generation: index
                ),
                reason: .autosave,
                date: Date(timeIntervalSince1970: Double(index)),
                regionDeltaPaths: ["regions/r.\(index).0.0.isoregion"],
                blobHashes: [StableHash(UInt64(index)).description],
                summary: "autosave \(index)"
            )
        }

        let retained = store.retained(
            policy: SnapshotRetentionPolicy(
                autosaveLimit: 2,
                manualLimit: 3,
                checkpointLimit: 1,
                keepPreMigration: true
            )
        )

        XCTAssertEqual(store.snapshots.count, 4)
        XCTAssertEqual(retained.snapshots.count, 2)
        XCTAssertEqual(retained.snapshots.map(\.generation), [2, 3])
        XCTAssertEqual(retained.snapshots.first?.relativePath, "snapshots/2.isosnapshot")
    }

    func testMigrationManagerPlansSchemaOneToCurrentSaveVersion() {
        let source = SaveVersion(formatVersion: 1, schemaVersion: 1)
        let manager = MigrationManager()
        let strict = manager.plan(from: source, to: .current, mode: .strict)
        let migrated = manager.plan(from: source, to: .current, mode: .migrated)
        let report = manager.report(for: migrated, at: Date(timeIntervalSince1970: 50))

        XCTAssertEqual(strict.status, .blocked)
        XCTAssertEqual(migrated.status, .ready)
        XCTAssertEqual(migrated.rules.map(\.systemID), ["persistence.region-deltas"])
        XCTAssertTrue(migrated.requiresBackup)
        XCTAssertTrue(report.success)
        XCTAssertEqual(report.migratedSystems, ["persistence.region-deltas"])
    }

    func testMigrationLabRunsCorpusAgainstCurrentRules() {
        let lab = MigrationLab()
        let report = lab.run(samples: [
            MigrationCorpusSample(
                sampleID: "schema-1-region-deltas",
                sourceVersion: SaveVersion(formatVersion: 1, schemaVersion: 1),
                mode: .migrated
            ),
            MigrationCorpusSample(
                sampleID: "current",
                sourceVersion: .current,
                mode: .strict
            ),
        ])

        XCTAssertTrue(report.isReady)
        XCTAssertEqual(report.checkedSamples, 2)
        XCTAssertEqual(report.blockedSamples, 0)
        XCTAssertEqual(report.migratedSystems, ["persistence.region-deltas"])
    }

    func testToolAssetAndGraphPackagesValidateHashAndRoundTrip() throws {
        let graph = GraphPackage(
            graphID: StableID(3001),
            kind: .terrainRecipe,
            displayName: "Terrain recipe",
            nodes: [
                GraphPackageNode(nodeID: "input", kind: "seed", title: "Seed"),
                GraphPackageNode(nodeID: "output", kind: "terrain", title: "Terrain")
            ],
            edges: [
                GraphPackageEdge(
                    edgeID: "seed-to-terrain",
                    fromNodeID: "input",
                    fromPort: "seed",
                    toNodeID: "output",
                    toPort: "height"
                )
            ],
            parameters: ["lod": "auto"]
        )
        let asset = AssetPackage(
            assetID: StableID(3002),
            type: .proceduralPropGenerator,
            displayName: "Prop set",
            tags: [.exploration, .exploration],
            source: AssetSourceManifest(
                graphPath: graph.relativePath,
                sourceAssetPaths: ["props/tree.json", "props/rock.json"]
            ),
            runtimeExport: RuntimeExportManifest(
                path: "blobs/props.bundle",
                contentHash: StableHash(1234)
            )
        )
        let project = ToolProjectPackage(
            projectID: StableID(3003),
            kind: .terrainRecipeEditor,
            displayName: "Terrain tools",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            graphPackage: graph,
            assetPackageIDs: [asset.assetID, asset.assetID],
            metadata: ["owner": "engine"]
        )
        let projectData = try AtomicFileWriter.makeJSONEncoder().encode(project)
        let decodedProject = try AtomicFileWriter.makeJSONDecoder().decode(ToolProjectPackage.self, from: projectData)

        XCTAssertTrue(graph.validationReport.isValid)
        XCTAssertTrue(asset.validationReport.isValid)
        XCTAssertTrue(project.validationReport.isValid)
        XCTAssertEqual(graph.relativePath, "graphs/terrainRecipe/\(graph.graphID).isograph")
        XCTAssertEqual(asset.relativePath, "assets/proceduralPropGenerator/\(asset.assetID).isoasset")
        XCTAssertEqual(asset.tags, [.exploration])
        XCTAssertEqual(project.assetPackageIDs, [asset.assetID])
        XCTAssertEqual(project.relativePath, "projects/terrainRecipeEditor/\(project.projectID).isoproj")
        XCTAssertEqual(decodedProject, project)
        XCTAssertEqual(
            graph.contentHash,
            GraphPackage(
                graphID: graph.graphID,
                kind: graph.kind,
                displayName: graph.displayName,
                nodes: graph.nodes.reversed(),
                edges: graph.edges,
                parameters: graph.parameters
            ).contentHash
        )
    }

    private func makeManifest(
        slotID: SaveSlotID,
        seedText: String,
        date: Date = Date(timeIntervalSince1970: 100)
    ) -> SaveManifest {
        let worldSeed = WorldSeed(StableHash.make { builder in
            builder.combine(seedText)
        }.value)

        return SaveManifest.newWorld(
            slotID: slotID,
            displayName: "Save \(slotID.rawValue)",
            worldName: "World \(seedText)",
            seedText: seedText,
            worldSeed: worldSeed,
            playerProfile: PlayerProfile(displayName: "Tester"),
            playerPosition: WorldPosition(x: 12, y: 3, z: -8),
            createdAt: date
        )
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "IsoWorldPersistenceTests-\(UUID().uuidString)",
            isDirectory: true
        )
    }
}
