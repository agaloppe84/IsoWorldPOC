public struct WorldSeed: Hashable, Codable, Sendable {
    public let value: UInt64

    public init(_ value: UInt64) {
        self.value = value
    }
}

extension WorldSeed: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(value)
    }
}

