public struct ChunkGenerator: Sendable {
    public let seed: WorldSeed
    private let heightFunction: TerrainHeightFunction

    public init(seed: WorldSeed) {
        self.seed = seed
        heightFunction = TerrainHeightFunction(seed: seed)
    }

    public func generateHeightmap(for coordinate: ChunkCoordinate) -> ChunkHeightmap {
        var samples: [TerrainSample] = []
        samples.reserveCapacity(ChunkHeightmap.sampleCount)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                samples.append(sample(localX: localX, localZ: localZ, in: coordinate))
            }
        }

        return ChunkHeightmap(seed: seed, coordinate: coordinate, samples: samples)
    }

    public func sample(localX: Int, localZ: Int, in coordinate: ChunkCoordinate) -> TerrainSample {
        precondition(ChunkHeightmap.contains(localX: localX, localZ: localZ), "Terrain sample index out of bounds.")

        let worldX = coordinate.x * ChunkHeightmap.gridStride + localX
        let worldZ = coordinate.z * ChunkHeightmap.gridStride + localZ
        let height = heightFunction.heightAt(worldX: worldX, worldZ: worldZ, verticalChunk: coordinate.y)

        return TerrainSample(
            localX: localX,
            localZ: localZ,
            worldX: worldX,
            worldZ: worldZ,
            height: height
        )
    }
}
