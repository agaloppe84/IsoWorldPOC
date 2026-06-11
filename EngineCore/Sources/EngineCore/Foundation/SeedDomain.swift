public struct SeedDomain: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "SeedDomain cannot be empty.")
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.init(rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public var description: String {
        rawValue
    }
}

public extension SeedDomain {
    static let worldDNA = SeedDomain("world-dna")
    static let terrain = SeedDomain("terrain")
    static let biomes = SeedDomain("biomes")
    static let biome = SeedDomain("biomes")
    static let render = SeedDomain("render")
    static let rpg = SeedDomain("rpg")
    static let style = SeedDomain("style")
    static let chunks = SeedDomain("chunks")
    static let props = SeedDomain("props")
    static let entities = SeedDomain("entities")
    static let characters = SeedDomain("characters")
    static let climate = SeedDomain("climate")
    static let heightmap = SeedDomain("heightmap")
    static let terrainFeatures = SeedDomain("terrain-features")
    static let traversal = SeedDomain("traversal")
}
