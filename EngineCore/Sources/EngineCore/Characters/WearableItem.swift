public enum WearableItemKind: String, CaseIterable, Codable, Sendable {
    case hair
    case clothing
    case armor
    case accessory
    case tool
    case weapon
}

public struct WearableItem: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: WearableItemKind
    public let identifier: String
    public let displayName: String
    public let occupiedSlots: [EquipmentSlot]
    public let material: CharacterPBRMaterial
    public let massKilograms: Float
    public let insulation: Float
    public let armorRating: Float
    public let durability: Float
    public let styleTags: [String]

    public init(
        id: StableID,
        kind: WearableItemKind,
        identifier: String,
        displayName: String,
        occupiedSlots: [EquipmentSlot],
        material: CharacterPBRMaterial,
        massKilograms: Float = 0,
        insulation: Float = 0,
        armorRating: Float = 0,
        durability: Float = 1,
        styleTags: [String] = []
    ) {
        precondition(!identifier.isEmpty, "WearableItem identifier cannot be empty.")
        precondition(!displayName.isEmpty, "WearableItem displayName cannot be empty.")
        precondition(!occupiedSlots.isEmpty, "WearableItem must occupy at least one slot.")

        self.id = id
        self.kind = kind
        self.identifier = identifier
        self.displayName = displayName
        self.occupiedSlots = occupiedSlots
        self.material = material
        self.massKilograms = max(massKilograms, 0)
        self.insulation = Self.clamped01(insulation)
        self.armorRating = Self.clamped01(armorRating)
        self.durability = Self.clamped01(durability)
        self.styleTags = styleTags
    }

    public func occupies(_ slot: EquipmentSlot) -> Bool {
        occupiedSlots.contains(slot)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct CharacterEquipmentSet: Equatable, Hashable, Codable, Sendable {
    public let items: [WearableItem]

    public init(items: [WearableItem] = []) {
        var resolved: [WearableItem] = []

        for item in items {
            resolved.removeAll { existing in
                !Set(existing.occupiedSlots).isDisjoint(with: item.occupiedSlots)
            }
            resolved.append(item)
        }

        self.items = resolved.sorted { $0.identifier < $1.identifier }
    }

    public func item(in slot: EquipmentSlot) -> WearableItem? {
        items.first { $0.occupies(slot) }
    }

    public func equipping(_ item: WearableItem) -> CharacterEquipmentSet {
        CharacterEquipmentSet(items: items + [item])
    }

    public var occupiedSlots: Set<EquipmentSlot> {
        Set(items.flatMap(\.occupiedSlots))
    }

    public var carriedMassKilograms: Float {
        items.reduce(0) { $0 + $1.massKilograms }
    }

    public static func starterOutfit(
        worldSeed: WorldSeed,
        characterID: StableID,
        random: inout StableRNG
    ) -> CharacterEquipmentSet {
        let clothColor = BiomeColor(
            red: random.nextFloat(in: 0.18...0.42),
            green: random.nextFloat(in: 0.22...0.48),
            blue: random.nextFloat(in: 0.20...0.52)
        )
        let leather = CharacterPBRMaterial(
            identifier: "character.material.leather.v1",
            debugName: "Leather",
            baseColor: BiomeColor(red: 0.28, green: 0.16, blue: 0.09),
            roughness: 0.78
        )
        let cloth = CharacterPBRMaterial(
            identifier: "character.material.cloth.seeded",
            debugName: "Cloth",
            baseColor: clothColor,
            roughness: 0.86
        )
        let metal = CharacterPBRMaterial(
            identifier: "character.material.tool-metal.v1",
            debugName: "Tool metal",
            baseColor: BiomeColor(red: 0.55, green: 0.56, blue: 0.54),
            roughness: 0.42,
            metallic: 0.75
        )

        return CharacterEquipmentSet(items: [
            WearableItem(
                id: itemID(worldSeed: worldSeed, characterID: characterID, identifier: "starter-tunic"),
                kind: .clothing,
                identifier: "starter.tunic",
                displayName: "Starter tunic",
                occupiedSlots: [.torso],
                material: cloth,
                massKilograms: 0.7,
                insulation: 0.35,
                styleTags: ["starter", "cloth"]
            ),
            WearableItem(
                id: itemID(worldSeed: worldSeed, characterID: characterID, identifier: "starter-trousers"),
                kind: .clothing,
                identifier: "starter.trousers",
                displayName: "Starter trousers",
                occupiedSlots: [.legs],
                material: cloth,
                massKilograms: 0.55,
                insulation: 0.28,
                styleTags: ["starter", "cloth"]
            ),
            WearableItem(
                id: itemID(worldSeed: worldSeed, characterID: characterID, identifier: "starter-boots"),
                kind: .clothing,
                identifier: "starter.boots",
                displayName: "Starter boots",
                occupiedSlots: [.feet],
                material: leather,
                massKilograms: 0.9,
                insulation: 0.22,
                armorRating: 0.08,
                styleTags: ["starter", "leather"]
            ),
            WearableItem(
                id: itemID(worldSeed: worldSeed, characterID: characterID, identifier: "starter-pack"),
                kind: .accessory,
                identifier: "starter.pack",
                displayName: "Starter pack",
                occupiedSlots: [.back],
                material: leather,
                massKilograms: 1.4,
                styleTags: ["starter", "storage"]
            ),
            WearableItem(
                id: itemID(worldSeed: worldSeed, characterID: characterID, identifier: "starter-tool"),
                kind: .tool,
                identifier: "starter.tool",
                displayName: "Starter tool",
                occupiedSlots: [.rightHand],
                material: metal,
                massKilograms: 1.1,
                durability: 0.85,
                styleTags: ["starter", "tool"]
            ),
        ])
    }

    private static func itemID(
        worldSeed: WorldSeed,
        characterID: StableID,
        identifier: String
    ) -> StableID {
        var hasher = StableHash.Builder()
        hasher.combine(worldSeed)
        hasher.combine(SeedDomain.characters)
        hasher.combine("wearable")
        hasher.combine(characterID.rawValue)
        hasher.combine(identifier)
        return StableID(hasher.finalize().value)
    }
}
