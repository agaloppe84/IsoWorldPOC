public struct TerrainSystem: Sendable {
    public let seed: WorldSeed

    private let chunkGenerator: TerrainChunkGenerator

    public init(seed: WorldSeed) {
        self.seed = seed
        self.chunkGenerator = TerrainChunkGenerator(seed: seed)
    }

    public func sampleGrid(for coordinate: ChunkCoordinate) -> TerrainSampleGrid {
        chunkGenerator.generateSampleGrid(for: coordinate)
    }

    public func sample(
        localX: Int,
        localZ: Int,
        in coordinate: ChunkCoordinate
    ) -> TerrainSample {
        chunkGenerator.sample(localX: localX, localZ: localZ, in: coordinate)
    }

    public func heightmap(for coordinate: ChunkCoordinate) -> ChunkHeightmap {
        ChunkHeightmap(sampleGrid: sampleGrid(for: coordinate))
    }

    public func terrainVertexMaterials(for coordinate: ChunkCoordinate) -> [TerrainVertexMaterial] {
        chunkGenerator.terrainVertexMaterials(for: coordinate)
    }

    public func featureGraph() -> TerrainFeatureGraph {
        chunkGenerator.featureGraph()
    }

    public func features(intersecting coordinate: ChunkCoordinate) -> TerrainFeatureChunkQuery {
        chunkGenerator.featureGraph().features(intersecting: coordinate)
    }

    public func traversalData(for coordinate: ChunkCoordinate) -> TraversalChunkData {
        chunkGenerator.traversalData(for: coordinate)
    }

    public func validationReport(for coordinate: ChunkCoordinate) -> TerrainValidationReport {
        sampleGrid(for: coordinate).validationReport
    }
}
