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
    static let rpgDNA = SeedDomain("rpg.dna")
    static let rpgRules = SeedDomain("rpg.rules")
    static let rpgFactions = SeedDomain("rpg.factions")
    static let rpgObjectives = SeedDomain("rpg.objectives")
    static let rpgQuests = SeedDomain("rpg.quests")
    static let rpgLedger = SeedDomain("rpg.ledger")
    static let settlements = SeedDomain("settlements")
    static let settlementRecipes = SeedDomain("settlements.recipes")
    static let settlementSites = SeedDomain("settlements.sites")
    static let buildingIntents = SeedDomain("settlements.building-intents")
    static let buildingFootprints = SeedDomain("settlements.footprints")
    static let buildingMassing = SeedDomain("settlements.massing")
    static let style = SeedDomain("style")
    static let chunks = SeedDomain("chunks")
    static let props = SeedDomain("props")
    static let entities = SeedDomain("entities")
    static let characters = SeedDomain("characters")
    static let animation = SeedDomain("animation")
    static let fx = SeedDomain("fx")
    static let audio = SeedDomain("audio")
    static let ui = SeedDomain("ui")
    static let climate = SeedDomain("climate")
    static let heightmap = SeedDomain("heightmap")
    static let terrainFeatures = SeedDomain("terrain-features")
    static let traversal = SeedDomain("traversal")
}
