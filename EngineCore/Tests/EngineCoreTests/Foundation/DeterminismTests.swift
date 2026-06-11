import Foundation
import XCTest
@testable import EngineCore

final class DeterminismTests: XCTestCase {
    func testStableRNGIsDeterministicForSameSeedDomainAndCoordinate() {
        let seed = WorldSeed(0xCAFE_BABE)
        let coordinate = ChunkCoordinate(x: -4, y: 1, z: 9)
        var first = StableRNG(seed: seed, domain: .terrain, coordinate: coordinate)
        var second = StableRNG(seed: seed, domain: .terrain, coordinate: coordinate)

        XCTAssertEqual(nextValues(from: &first), nextValues(from: &second))
    }

    func testStableRNGChangesAcrossCoordinatesAndDomains() {
        let seed = WorldSeed(0xCAFE_BABE)
        var origin = StableRNG(seed: seed, domain: .terrain, coordinate: .origin)
        var neighbor = StableRNG(seed: seed, domain: .terrain, coordinate: ChunkCoordinate(x: 1, y: 0, z: 0))
        var props = StableRNG(seed: seed, domain: .props, coordinate: .origin)

        XCTAssertNotEqual(nextValues(from: &origin), nextValues(from: &neighbor))

        var originAgain = StableRNG(seed: seed, domain: .terrain, coordinate: .origin)
        XCTAssertNotEqual(nextValues(from: &originAgain), nextValues(from: &props))
    }

    func testStableHashDoesNotUseProcessRandomizedHasher() {
        let first = StableHash.make { builder in
            builder.combine(WorldSeed(99))
            builder.combine(SeedDomain.terrain)
            builder.combine(ChunkCoordinate(x: -2, y: 0, z: 7))
        }
        let second = StableHash.make { builder in
            builder.combine(WorldSeed(99))
            builder.combine(SeedDomain.terrain)
            builder.combine(ChunkCoordinate(x: -2, y: 0, z: 7))
        }
        let other = StableHash.make { builder in
            builder.combine(WorldSeed(99))
            builder.combine(SeedDomain.terrain)
            builder.combine(ChunkCoordinate(x: -2, y: 0, z: 8))
        }

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, other)
    }

    func testStableIDIsIndependentFromGenerationOrder() {
        let seed = WorldSeed(42)
        let firstChunk = ChunkCoordinate(x: -1, y: 0, z: 3)
        let secondChunk = ChunkCoordinate(x: 4, y: 0, z: -2)

        let chunkIDs = [
            StableID.chunk(worldSeed: seed, coordinate: firstChunk),
            StableID.chunk(worldSeed: seed, coordinate: secondChunk),
        ]
        let reversedIDs = [
            StableID.chunk(worldSeed: seed, coordinate: secondChunk),
            StableID.chunk(worldSeed: seed, coordinate: firstChunk),
        ]

        XCTAssertEqual(chunkIDs[0], reversedIDs[1])
        XCTAssertEqual(chunkIDs[1], reversedIDs[0])
        XCTAssertNotEqual(chunkIDs[0], chunkIDs[1])
    }

    func testStableIDsSeparateChunksPropsAndEntities() {
        let seed = WorldSeed(42)
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let chunkID = StableID.chunk(worldSeed: seed, coordinate: coordinate)
        let propID = StableID.prop(worldSeed: seed, coordinate: coordinate, placementIndex: 0)
        let entityID = StableID.entity(worldSeed: seed, localIndex: 0)

        XCTAssertNotEqual(chunkID, propID)
        XCTAssertNotEqual(propID, entityID)
        XCTAssertNotEqual(chunkID, entityID)
        XCTAssertEqual(propID, StableID.prop(worldSeed: seed, coordinate: coordinate, placementIndex: 0))
        XCTAssertNotEqual(propID, StableID.prop(worldSeed: seed, coordinate: coordinate, placementIndex: 1))
    }

    func testWorldDNAIsDeterministicAndCodable() throws {
        let seed = GoldenWorldSeeds.plains
        let first = WorldDNA.make(worldSeed: seed)
        let second = WorldDNA.make(worldSeed: seed)
        let data = try JSONEncoder().encode(first)
        let decoded = try JSONDecoder().decode(WorldDNA.self, from: data)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, decoded)
    }

    func testWorldDNAChangesAcrossSeeds() {
        let plains = WorldDNA.make(worldSeed: GoldenWorldSeeds.plains)
        let mountains = WorldDNA.make(worldSeed: GoldenWorldSeeds.mountains)

        XCTAssertNotEqual(plains, mountains)
    }

    func testWorldDNAHashChangesWhenGeneratorVersionChanges() {
        let seed = WorldSeed(123)
        let current = GeneratorVersionTable.current
        let terrainV2 = current.setting(GeneratorVersion(major: 2), for: .terrain)

        let first = WorldDNA.make(worldSeed: seed, generatorVersions: current)
        let second = WorldDNA.make(worldSeed: seed, generatorVersions: terrainV2)

        XCTAssertNotEqual(first.terrain, second.terrain)
        XCTAssertEqual(first.biomes, second.biomes)
        XCTAssertEqual(first.render, second.render)
        XCTAssertEqual(first.rpg, second.rpg)
        XCTAssertEqual(first.style, second.style)
    }

    func testGenerationContextCreatesVersionedRNGsAndIDs() {
        let coordinate = ChunkCoordinate(x: -3, y: 0, z: 5)
        let context = GenerationContext(worldSeed: WorldSeed(777), domain: .chunks)
        var first = context.rng(coordinate: coordinate)
        var second = context.rng(coordinate: coordinate)
        let id = context.stableID(coordinate: coordinate)

        XCTAssertEqual(context.worldDNA, WorldDNA.make(worldSeed: WorldSeed(777)))
        XCTAssertEqual(nextValues(from: &first), nextValues(from: &second))
        XCTAssertEqual(id, context.stableID(coordinate: coordinate))
        XCTAssertNotEqual(id, context.stableID(coordinate: coordinate.offsetBy(x: 1)))
    }

    func testGoldenSeedsAreUniqueAndNamed() {
        XCTAssertEqual(Set(GoldenWorldSeeds.all).count, GoldenWorldSeeds.all.count)
        XCTAssertEqual(GoldenWorldSeeds.named.map(\.seed), GoldenWorldSeeds.all)
        XCTAssertEqual(Set(GoldenWorldSeeds.named.map(\.name)).count, GoldenWorldSeeds.named.count)
    }

    func testRegionCoordinateUsesFloorDivisionForNegativeChunks() {
        XCTAssertEqual(
            RegionCoordinate.containing(ChunkCoordinate(x: -1, y: 0, z: -8), regionSizeInChunks: 8),
            RegionCoordinate(x: -1, y: 0, z: -1)
        )
        XCTAssertEqual(
            RegionCoordinate.containing(ChunkCoordinate(x: -9, y: 0, z: 8), regionSizeInChunks: 8),
            RegionCoordinate(x: -2, y: 0, z: 1)
        )
        XCTAssertEqual(
            RegionCoordinate(x: -2, y: 0, z: 1).chunkOrigin(regionSizeInChunks: 8),
            ChunkCoordinate(x: -16, y: 0, z: 8)
        )
    }

    private func nextValues(from random: inout StableRNG) -> [UInt64] {
        (0..<8).map { _ in random.next() }
    }
}
