public struct TerrainFeatureChunkQuery: Equatable, Codable, Sendable {
    public let coordinate: ChunkCoordinate
    public let mountainRanges: [MountainRangeFeature]
    public let rivers: [RiverFeature]
    public let lakes: [LakeFeature]
    public let cliffBands: [CliffBandFeature]

    public var featureCount: Int {
        mountainRanges.count + rivers.count + lakes.count + cliffBands.count
    }

    public var isEmpty: Bool {
        featureCount == 0
    }

    public var featureIDs: [StableID] {
        mountainRanges.map(\.id) +
            rivers.map(\.id) +
            lakes.map(\.id) +
            cliffBands.map(\.id)
    }
}

public struct TerrainFeatureGraph: Equatable, Codable, Sendable {
    public let seed: WorldSeed
    public let mountainRanges: [MountainRangeFeature]
    public let rivers: [RiverFeature]
    public let lakes: [LakeFeature]
    public let cliffBands: [CliffBandFeature]

    public init(
        seed: WorldSeed,
        mountainRanges: [MountainRangeFeature],
        rivers: [RiverFeature],
        lakes: [LakeFeature],
        cliffBands: [CliffBandFeature]
    ) {
        self.seed = seed
        self.mountainRanges = mountainRanges
        self.rivers = rivers
        self.lakes = lakes
        self.cliffBands = cliffBands
    }

    public static func make(seed: WorldSeed) -> TerrainFeatureGraph {
        var random = StableRNG(seed: seed, domain: .terrainFeatures)

        let rivers = [
            RiverFeature(
                id: featureID(seed: seed, index: 0),
                startX: -180,
                startZ: random.nextFloat(in: (-8)...8),
                endX: 180,
                endZ: random.nextFloat(in: (-8)...8),
                width: random.nextFloat(in: 7...10),
                shoreWidth: random.nextFloat(in: 7...11),
                carveDepth: random.nextFloat(in: 1.2...2.1),
                waterDepth: random.nextFloat(in: 0.35...0.70)
            ),
            RiverFeature(
                id: featureID(seed: seed, index: 1),
                startX: random.nextFloat(in: (-120)...(-80)),
                startZ: 150,
                endX: random.nextFloat(in: 70...120),
                endZ: -150,
                width: random.nextFloat(in: 5...8),
                shoreWidth: random.nextFloat(in: 5...8),
                carveDepth: random.nextFloat(in: 0.8...1.6),
                waterDepth: random.nextFloat(in: 0.25...0.55)
            ),
        ]

        let lakes = [
            LakeFeature(
                id: featureID(seed: seed, index: 2),
                centerX: random.nextFloat(in: 28...58),
                centerZ: random.nextFloat(in: (-64)...(-28)),
                radius: random.nextFloat(in: 16...28),
                shoreWidth: random.nextFloat(in: 6...10),
                basinDepth: random.nextFloat(in: 1.0...2.0),
                waterDepth: random.nextFloat(in: 0.45...0.9)
            ),
            LakeFeature(
                id: featureID(seed: seed, index: 3),
                centerX: random.nextFloat(in: (-90)...(-52)),
                centerZ: random.nextFloat(in: 42...86),
                radius: random.nextFloat(in: 12...22),
                shoreWidth: random.nextFloat(in: 5...9),
                basinDepth: random.nextFloat(in: 0.8...1.6),
                waterDepth: random.nextFloat(in: 0.35...0.75)
            ),
        ]

        let mountainRanges = [
            MountainRangeFeature(
                id: featureID(seed: seed, index: 4),
                centerX: random.nextFloat(in: (-115)...(-70)),
                centerZ: random.nextFloat(in: (-95)...(-42)),
                length: random.nextFloat(in: 110...170),
                width: random.nextFloat(in: 18...32),
                angleRadians: random.nextFloat(in: (-0.8)...0.3),
                amplitude: random.nextFloat(in: 4.5...8.5)
            ),
            MountainRangeFeature(
                id: featureID(seed: seed, index: 5),
                centerX: random.nextFloat(in: 70...120),
                centerZ: random.nextFloat(in: 60...120),
                length: random.nextFloat(in: 90...150),
                width: random.nextFloat(in: 15...28),
                angleRadians: random.nextFloat(in: 0.5...1.3),
                amplitude: random.nextFloat(in: 3.5...7.0)
            ),
        ]

        let cliffBands = [
            CliffBandFeature(
                id: featureID(seed: seed, index: 6),
                centerX: random.nextFloat(in: (-54)...(-20)),
                centerZ: random.nextFloat(in: (-18)...28),
                length: random.nextFloat(in: 70...130),
                width: random.nextFloat(in: 5...9),
                angleRadians: random.nextFloat(in: (-0.4)...0.8),
                heightStep: random.nextFloat(in: 1.4...3.0)
            ),
            CliffBandFeature(
                id: featureID(seed: seed, index: 7),
                centerX: random.nextFloat(in: 34...72),
                centerZ: random.nextFloat(in: 10...68),
                length: random.nextFloat(in: 60...110),
                width: random.nextFloat(in: 4...8),
                angleRadians: random.nextFloat(in: 1.2...2.1),
                heightStep: random.nextFloat(in: 1.1...2.4)
            ),
        ]

        return TerrainFeatureGraph(
            seed: seed,
            mountainRanges: mountainRanges,
            rivers: rivers,
            lakes: lakes,
            cliffBands: cliffBands
        )
    }

    public var featureCount: Int {
        mountainRanges.count + rivers.count + lakes.count + cliffBands.count
    }

    public func features(intersecting coordinate: ChunkCoordinate) -> TerrainFeatureChunkQuery {
        let chunkBounds = TerrainFeatureBounds.chunk(coordinate)

        return TerrainFeatureChunkQuery(
            coordinate: coordinate,
            mountainRanges: mountainRanges.filter { $0.bounds.intersects(chunkBounds) },
            rivers: rivers.filter { $0.bounds.intersects(chunkBounds) },
            lakes: lakes.filter { $0.bounds.intersects(chunkBounds) },
            cliffBands: cliffBands.filter { $0.bounds.intersects(chunkBounds) }
        )
    }

    public func contribution(at point: TerrainFeaturePoint) -> TerrainFeatureContribution {
        var contribution = TerrainFeatureContribution.zero

        for mountainRange in mountainRanges where mountainRange.bounds.contains(point) {
            contribution = contribution.merged(with: mountainRange.contribution(at: point))
        }

        for river in rivers where river.bounds.contains(point) {
            contribution = contribution.merged(with: river.contribution(at: point))
        }

        for lake in lakes where lake.bounds.contains(point) {
            contribution = contribution.merged(with: lake.contribution(at: point))
        }

        for cliffBand in cliffBands where cliffBand.bounds.contains(point) {
            contribution = contribution.merged(with: cliffBand.contribution(at: point))
        }

        return contribution
    }

    private static func featureID(seed: WorldSeed, index: Int) -> StableID {
        StableID.make(
            worldSeed: seed,
            domain: .terrainFeatures,
            values: [UInt64(bitPattern: Int64(index))]
        )
    }
}
