public struct StableHash: Hashable, Codable, Sendable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    public static let offsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325
    public static let prime: UInt64 = 0x0000_0100_0000_01b3

    public let value: UInt64

    public init(_ value: UInt64) {
        self.value = value
    }

    public init(integerLiteral value: UInt64) {
        self.init(value)
    }

    public var description: String {
        let hex = String(value, radix: 16)
        return "0x" + String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}

public extension StableHash {
    struct Builder: Sendable {
        public private(set) var value: UInt64

        public init(seed: UInt64 = StableHash.offsetBasis) {
            value = seed
        }

        public mutating func combine(_ value: UInt64) {
            self.value ^= StableHash.avalanche(value)
            self.value &*= StableHash.prime
        }

        public mutating func combine(_ value: Int) {
            combine(UInt64(bitPattern: Int64(value)))
        }

        public mutating func combine(_ value: Float) {
            combine(UInt64(value.bitPattern))
        }

        public mutating func combine(_ value: String) {
            combine(value.utf8.count)

            for byte in value.utf8 {
                combine(UInt64(byte))
            }
        }

        public mutating func combine(_ seed: WorldSeed) {
            combine(seed.value)
        }

        public mutating func combine(_ domain: SeedDomain) {
            combine(domain.rawValue)
        }

        public mutating func combine(_ coordinate: ChunkCoordinate) {
            combine(coordinate.x)
            combine(coordinate.y)
            combine(coordinate.z)
        }

        public mutating func combine(_ version: GeneratorVersion) {
            combine(version.major)
            combine(version.minor)
            combine(version.patch)
        }

        public func finalize() -> StableHash {
            StableHash(StableHash.avalanche(value))
        }
    }

    static func make(_ build: (inout Builder) -> Void) -> StableHash {
        var builder = Builder()
        build(&builder)
        return builder.finalize()
    }

    static func combine(_ values: UInt64...) -> StableHash {
        make { builder in
            for value in values {
                builder.combine(value)
            }
        }
    }

    static func seed(
        worldSeed: WorldSeed,
        domain: SeedDomain,
        coordinate: ChunkCoordinate? = nil,
        values: [UInt64] = []
    ) -> WorldSeed {
        WorldSeed(make { builder in
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

    static func avalanche(_ value: UInt64) -> UInt64 {
        var mixed = value
        mixed ^= mixed >> 30
        mixed &*= 0xbf58_476d_1ce4_e5b9
        mixed ^= mixed >> 27
        mixed &*= 0x94d0_49bb_1331_11eb
        return mixed ^ (mixed >> 31)
    }
}
