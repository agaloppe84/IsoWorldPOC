public struct PropContext: Equatable, Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let biome: Biome
    public let localX: Float
    public let localZ: Float
    public let terrainSample: TerrainSample

    public var slope: Float {
        terrainSample.slope
    }

    public var moisture: Float {
        terrainSample.moisture
    }

    public var temperature: Float {
        terrainSample.temperature
    }

    public var walkability: Float {
        terrainSample.walkability
    }

    public init(
        worldSeed: WorldSeed,
        coordinate: ChunkCoordinate,
        biome: Biome,
        localX: Float,
        localZ: Float,
        terrainSample: TerrainSample
    ) {
        self.worldSeed = worldSeed
        self.coordinate = coordinate
        self.biome = biome
        self.localX = localX
        self.localZ = localZ
        self.terrainSample = terrainSample
    }
}
