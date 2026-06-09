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

    func testTerrainMeshBuilderProducesOneVertexPerHeightmapSample() {
        let heightmap = ChunkGenerator(seed: WorldSeed(42)).generateHeightmap(for: .origin)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(mesh.vertices.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(mesh.normals.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(mesh.uvs.count, ChunkHeightmap.sampleCount)
        XCTAssertEqual(mesh.vertices.first, TerrainMesh.Vertex(x: 0, y: heightmap[0, 0].height, z: 0))
        XCTAssertEqual(mesh.vertices.last, TerrainMesh.Vertex(x: 63, y: heightmap[63, 63].height, z: 63))
    }

    func testTerrainMeshBuilderProducesExpectedTriangleIndices() {
        let heightmap = ChunkGenerator(seed: WorldSeed(42)).generateHeightmap(for: .origin)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)
        let expectedQuadCount = (ChunkHeightmap.resolution - 1) * (ChunkHeightmap.resolution - 1)

        XCTAssertEqual(mesh.indices.count, expectedQuadCount * 6)
        XCTAssertEqual(mesh.indices.prefix(6), [0, 64, 1, 1, 64, 65])
    }

    func testTerrainMeshBuilderProducesUpNormalsForFlatHeightmap() {
        let heightmap = flatHeightmap(height: 0)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(mesh.normals.first, TerrainMesh.Normal(x: 0, y: 1, z: 0))
        XCTAssertEqual(mesh.normals[ChunkHeightmap.resolution + 1], TerrainMesh.Normal(x: 0, y: 1, z: 0))
        XCTAssertEqual(mesh.normals.last, TerrainMesh.Normal(x: 0, y: 1, z: 0))
    }

    func testTerrainMeshBuilderProducesNormalizedNormals() {
        let heightmap = ChunkGenerator(seed: WorldSeed(42)).generateHeightmap(for: .origin)
        let mesh = TerrainMeshBuilder.build(from: heightmap, horizontalScale: 1, verticalScale: 1)

        for normal in [mesh.normals[0], mesh.normals[65], mesh.normals[ChunkHeightmap.sampleCount - 1]] {
            let length = (normal.x * normal.x + normal.y * normal.y + normal.z * normal.z).squareRoot()

            XCTAssertEqual(length, 1, accuracy: 0.0001)
            XCTAssertGreaterThan(normal.y, 0)
        }
    }

    func testTerrainSamplerReturnsExactGridHeights() {
        let heightmap = rampHeightmap()
        let sampler = TerrainSampler(heightmap: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(sampler.heightAt(x: 0, z: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(sampler.heightAt(x: 3, z: 4), 22, accuracy: 0.0001)
    }

    func testTerrainSamplerBilinearlyInterpolatesBetweenGridHeights() {
        let heightmap = rampHeightmap()
        let sampler = TerrainSampler(heightmap: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(sampler.heightAt(x: 0.5, z: 0.5), 3, accuracy: 0.0001)
    }

    func testTerrainSamplerAppliesScaleAndOrigin() {
        let heightmap = rampHeightmap()
        let sampler = TerrainSampler(
            heightmap: heightmap,
            horizontalScale: 0.5,
            verticalScale: 2,
            originX: -10,
            originZ: 5
        )

        XCTAssertEqual(sampler.heightAt(x: -9.5, z: 6), 20, accuracy: 0.0001)
    }

    func testTerrainSamplerReportsFlatSlopeAsZero() {
        let heightmap = flatHeightmap(height: 3)
        let sampler = TerrainSampler(heightmap: heightmap, horizontalScale: 1, verticalScale: 1)

        XCTAssertEqual(sampler.slopeAt(x: 20, z: 20), 0, accuracy: 0.0001)
    }

    func testTerrainSamplerReportsSlopeForRamps() {
        let heightmap = rampHeightmap()
        let sampler = TerrainSampler(heightmap: heightmap, horizontalScale: 1, verticalScale: 1)
        let sample = sampler.sampleAt(x: 20, z: 20)

        XCTAssertEqual(sample.height, 120, accuracy: 0.0001)
        XCTAssertGreaterThan(sample.slope, 0)
    }

    private func flatHeightmap(height: Float) -> ChunkHeightmap {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                samples.append(
                    TerrainSample(
                        localX: localX,
                        localZ: localZ,
                        worldX: localX,
                        worldZ: localZ,
                        height: height
                    )
                )
            }
        }

        return ChunkHeightmap(seed: WorldSeed(1), coordinate: .origin, samples: samples)
    }

    private func rampHeightmap() -> ChunkHeightmap {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                samples.append(
                    TerrainSample(
                        localX: localX,
                        localZ: localZ,
                        worldX: localX,
                        worldZ: localZ,
                        height: Float(localX * 2 + localZ * 4)
                    )
                )
            }
        }

        return ChunkHeightmap(seed: WorldSeed(1), coordinate: .origin, samples: samples)
    }
}
