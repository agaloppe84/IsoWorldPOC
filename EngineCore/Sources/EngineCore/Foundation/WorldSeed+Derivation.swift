public extension WorldSeed {
    static let zero = WorldSeed(0)

    func derived(
        domain: SeedDomain,
        coordinate: ChunkCoordinate? = nil,
        values: [UInt64] = []
    ) -> WorldSeed {
        StableHash.seed(
            worldSeed: self,
            domain: domain,
            coordinate: coordinate,
            values: values
        )
    }
}

public struct GoldenWorldSeed: Hashable, Codable, Sendable {
    public let name: String
    public let seed: WorldSeed

    public init(name: String, seed: WorldSeed) {
        self.name = name
        self.seed = seed
    }
}

public enum GoldenWorldSeeds {
    public static let plains = WorldSeed(0x1000_0000_0000_0001)
    public static let mountains = WorldSeed(0x2000_0000_0000_0002)
    public static let river = WorldSeed(0x3000_0000_0000_0003)
    public static let desert = WorldSeed(0x4000_0000_0000_0004)
    public static let denseForest = WorldSeed(0x5000_0000_0000_0005)
    public static let biomeTransition = WorldSeed(0x6000_0000_0000_0006)
    public static let extremeHeight = WorldSeed(0x7000_0000_0000_0007)

    public static let all: [WorldSeed] = [
        plains,
        mountains,
        river,
        desert,
        denseForest,
        biomeTransition,
        extremeHeight,
    ]

    public static let named: [GoldenWorldSeed] = [
        GoldenWorldSeed(name: "plains", seed: plains),
        GoldenWorldSeed(name: "mountains", seed: mountains),
        GoldenWorldSeed(name: "river", seed: river),
        GoldenWorldSeed(name: "desert", seed: desert),
        GoldenWorldSeed(name: "dense-forest", seed: denseForest),
        GoldenWorldSeed(name: "biome-transition", seed: biomeTransition),
        GoldenWorldSeed(name: "extreme-height", seed: extremeHeight),
    ]
}
