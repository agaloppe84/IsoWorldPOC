public struct ChunkGenerator: Sendable {
    public let seed: WorldSeed
    private let terrainGenerator: TerrainChunkGenerator

    public init(seed: WorldSeed) {
        self.seed = seed
        terrainGenerator = TerrainChunkGenerator(seed: seed)
    }

    public func generateHeightmap(for coordinate: ChunkCoordinate) -> ChunkHeightmap {
        ChunkHeightmap(sampleGrid: terrainGenerator.generateSampleGrid(for: coordinate))
    }

    public func sample(localX: Int, localZ: Int, in coordinate: ChunkCoordinate) -> TerrainSample {
        precondition(ChunkHeightmap.contains(localX: localX, localZ: localZ), "Terrain sample index out of bounds.")

        return terrainGenerator.sample(localX: localX, localZ: localZ, in: coordinate)
    }
}
