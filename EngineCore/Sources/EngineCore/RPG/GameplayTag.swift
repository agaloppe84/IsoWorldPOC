public struct GameplayTag: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "GameplayTag cannot be empty.")
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

public extension GameplayTag {
    static let combat = GameplayTag("system.combat")
    static let nonViolent = GameplayTag("system.non_violent")
    static let exploration = GameplayTag("system.exploration")
    static let crafting = GameplayTag("system.crafting")
    static let factions = GameplayTag("system.factions")
    static let ecology = GameplayTag("system.ecology")
    static let mystery = GameplayTag("system.mystery")
    static let settlement = GameplayTag("system.settlement")
    static let survival = GameplayTag("system.survival")
    static let knowledge = GameplayTag("system.knowledge")
    static let trade = GameplayTag("system.trade")
    static let magic = GameplayTag("system.magic")
    static let technology = GameplayTag("system.technology")
    static let buildings = GameplayTag("system.buildings")
    static let architecture = GameplayTag("system.architecture")
    static let pathNetwork = GameplayTag("system.path_network")
    static let terrainAdapted = GameplayTag("system.terrain_adapted")
    static let threat = GameplayTag("system.threat")
    static let lowThreat = GameplayTag("system.low_threat")
    static let highThreat = GameplayTag("system.high_threat")
    static let social = GameplayTag("system.social")
    static let ruins = GameplayTag("world.ruins")
    static let climate = GameplayTag("world.climate")
    static let memory = GameplayTag("world.memory")
    static let ancientMachines = GameplayTag("world.ancient_machines")
    static let myth = GameplayTag("world.myth")
}

public extension Array where Element == GameplayTag {
    func uniquedStable() -> [GameplayTag] {
        var seen: Set<GameplayTag> = []
        var result: [GameplayTag] = []

        for tag in self where seen.insert(tag).inserted {
            result.append(tag)
        }

        return result
    }
}
