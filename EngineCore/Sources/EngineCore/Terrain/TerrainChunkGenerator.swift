public struct TerrainChunkGenerator: Sendable {
    public let seed: WorldSeed
    public let resolution: Int

    private let fieldProvider: DefaultTerrainFieldProvider

    public init(
        seed: WorldSeed,
        resolution: Int = ChunkHeightmap.resolution
    ) {
        precondition(resolution > 1, "TerrainChunkGenerator requires at least two samples per axis.")

        self.seed = seed
        self.resolution = resolution
        self.fieldProvider = DefaultTerrainFieldProvider(seed: seed)
    }

    public func generateSampleGrid(for coordinate: ChunkCoordinate) -> TerrainSampleGrid {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(resolution * resolution)

        for localZ in 0..<resolution {
            for localX in 0..<resolution {
                samples.append(sample(localX: localX, localZ: localZ, in: coordinate))
            }
        }

        return TerrainSampleGrid(
            seed: seed,
            coordinate: coordinate,
            resolution: resolution,
            samples: samples
        )
    }

    public func sample(
        localX: Int,
        localZ: Int,
        in coordinate: ChunkCoordinate
    ) -> TerrainSample {
        precondition((0..<resolution).contains(localX), "Terrain sample localX out of bounds.")
        precondition((0..<resolution).contains(localZ), "Terrain sample localZ out of bounds.")

        let worldX = coordinate.x * gridStride + localX
        let worldZ = coordinate.z * gridStride + localZ
        let fields = fieldProvider.sampleAt(
            worldX: worldX,
            worldZ: worldZ,
            verticalChunk: coordinate.y
        )

        return TerrainSample(
            localX: localX,
            localZ: localZ,
            worldX: worldX,
            worldZ: worldZ,
            height: fields.height,
            normal: fields.normal,
            slope: fields.slope,
            curvature: fields.curvature,
            roughness: fields.roughness,
            moisture: fields.moisture,
            temperature: fields.temperature,
            materialWeights: fields.materialWeights,
            walkability: fields.walkability,
            climbability: fields.climbability
        )
    }

    public func terrainVertexMaterials(for coordinate: ChunkCoordinate) -> [TerrainVertexMaterial] {
        generateSampleGrid(for: coordinate).samples.map { sample in
            sample.materialWeights.terrainVertexMaterial()
        }
    }

    private var gridStride: Int {
        resolution - 1
    }
}
