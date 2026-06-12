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
