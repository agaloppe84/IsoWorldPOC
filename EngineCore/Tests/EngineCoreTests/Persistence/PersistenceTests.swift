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
