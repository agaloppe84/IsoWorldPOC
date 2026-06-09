import XCTest
@testable import EngineCore

final class EngineCoreTests: XCTestCase {
    func testWorldSeedStoresRawValue() {
        let seed = WorldSeed(42)

        XCTAssertEqual(seed.value, 42)
    }

    func testChunkCoordinateStoresAxesAndOffsets() {
        let coordinate = ChunkCoordinate(x: 3, y: 1, z: -2)

        XCTAssertEqual(coordinate.x, 3)
        XCTAssertEqual(coordinate.y, 1)
        XCTAssertEqual(coordinate.z, -2)
        XCTAssertEqual(
            coordinate.offsetBy(x: -1, y: 2, z: 5),
            ChunkCoordinate(x: 2, y: 3, z: 3)
        )
    }

    func testSeededRandomIsDeterministicForSameSeed() {
        var first = SeededRandom(seed: WorldSeed(123_456))
        var second = SeededRandom(seed: WorldSeed(123_456))

        let firstValues = (0..<8).map { _ in first.next() }
        let secondValues = (0..<8).map { _ in second.next() }

        XCTAssertEqual(firstValues, secondValues)
    }

    func testSeededRandomDiffersForDifferentSeeds() {
        var first = SeededRandom(seed: WorldSeed(1))
        var second = SeededRandom(seed: WorldSeed(2))

        XCTAssertNotEqual(first.next(), second.next())
    }

    func testChunkGeneratorProduces64By64Heightmap() {
        let generator = ChunkGenerator(seed: WorldSeed(42))
        let heightmap = generator.generateHeightmap(for: .origin)

        XCTAssertEqual(ChunkHeightmap.resolution, 64)
        XCTAssertEqual(heightmap.samples.count, 64 * 64)
        XCTAssertEqual(heightmap[0, 0].localX, 0)
        XCTAssertEqual(heightmap[63, 63].localZ, 63)
        XCTAssertTrue(heightmap[12, 34].height.isFinite)
    }

    func testChunkGeneratorIsDeterministicForSameSeedAndChunk() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let first = ChunkGenerator(seed: WorldSeed(99)).generateHeightmap(for: coordinate)
        let second = ChunkGenerator(seed: WorldSeed(99)).generateHeightmap(for: coordinate)

        XCTAssertEqual(first.samples, second.samples)
        XCTAssertEqual(first.stableHash, second.stableHash)
    }

    func testChunkGeneratorDiffersForDifferentSeeds() {
        let coordinate = ChunkCoordinate(x: 2, y: 0, z: -3)
        let first = ChunkGenerator(seed: WorldSeed(99)).generateHeightmap(for: coordinate)
        let second = ChunkGenerator(seed: WorldSeed(100)).generateHeightmap(for: coordinate)

        XCTAssertNotEqual(first.samples, second.samples)
        XCTAssertNotEqual(first.stableHash, second.stableHash)
    }

    func testChunkGeneratorDiffersForDifferentChunks() {
        let generator = ChunkGenerator(seed: WorldSeed(99))
        let first = generator.generateHeightmap(for: ChunkCoordinate(x: 2, y: 0, z: -3))
        let second = generator.generateHeightmap(for: ChunkCoordinate(x: 3, y: 0, z: -3))

        XCTAssertNotEqual(first.samples, second.samples)
        XCTAssertNotEqual(first.stableHash, second.stableHash)
    }
}
