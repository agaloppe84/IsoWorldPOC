public struct StableID: Hashable, Codable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public let rawValue: UInt64

    public init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: UInt64) {
        self.init(value)
    }

    public var description: String {
        let hex = String(rawValue, radix: 16)
        return "0x" + String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}

public extension StableID {
    static func make(
        worldSeed: WorldSeed,
        domain: SeedDomain,
        coordinate: ChunkCoordinate? = nil,
        values: [UInt64] = []
    ) -> StableID {
        StableID(StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(domain)

            if let coordinate {
                builder.combine(coordinate)
            }

            for value in values {
                builder.combine(value)
            }
        }.value)
    }

    static func chunk(worldSeed: WorldSeed, coordinate: ChunkCoordinate) -> StableID {
        make(worldSeed: worldSeed, domain: .chunks, coordinate: coordinate)
    }

    static func prop(
        worldSeed: WorldSeed,
        coordinate: ChunkCoordinate,
        placementIndex: Int
    ) -> StableID {
        make(
            worldSeed: worldSeed,
            domain: .props,
            coordinate: coordinate,
            values: [UInt64(bitPattern: Int64(placementIndex))]
        )
    }

    static func entity(
        worldSeed: WorldSeed,
        domain: SeedDomain = .entities,
        localIndex: Int
    ) -> StableID {
        make(
            worldSeed: worldSeed,
            domain: domain,
            values: [UInt64(bitPattern: Int64(localIndex))]
        )
    }
}
