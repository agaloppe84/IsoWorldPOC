public enum CharacterMovementStance: String, CaseIterable, Codable, Sendable {
    case standing
    case crouching
    case climbing
    case swimming
}

public struct CharacterRuntimeState: Equatable, Hashable, Codable, Sendable {
    public let health: Float
    public let stamina: Float
    public let fatigue: Float
    public let wetness: Float
    public let dirtiness: Float
    public let movementStance: CharacterMovementStance
    public let equipment: CharacterEquipmentSet

    public init(
        health: Float = 1,
        stamina: Float = 1,
        fatigue: Float = 0,
        wetness: Float = 0,
        dirtiness: Float = 0,
        movementStance: CharacterMovementStance = .standing,
        equipment: CharacterEquipmentSet = CharacterEquipmentSet()
    ) {
        self.health = Self.clamped01(health)
        self.stamina = Self.clamped01(stamina)
        self.fatigue = Self.clamped01(fatigue)
        self.wetness = Self.clamped01(wetness)
        self.dirtiness = Self.clamped01(dirtiness)
        self.movementStance = movementStance
        self.equipment = equipment
    }

    public var isAlive: Bool {
        health > 0
    }

    public var carriedMassKilograms: Float {
        equipment.carriedMassKilograms
    }

    public func equipping(_ item: WearableItem) -> CharacterRuntimeState {
        CharacterRuntimeState(
            health: health,
            stamina: stamina,
            fatigue: fatigue,
            wetness: wetness,
            dirtiness: dirtiness,
            movementStance: movementStance,
            equipment: equipment.equipping(item)
        )
    }

    public func updatingEnvironmentalState(wetness: Float, dirtiness: Float) -> CharacterRuntimeState {
        CharacterRuntimeState(
            health: health,
            stamina: stamina,
            fatigue: fatigue,
            wetness: wetness,
            dirtiness: dirtiness,
            movementStance: movementStance,
            equipment: equipment
        )
    }

    public static func initial(equipment: CharacterEquipmentSet) -> CharacterRuntimeState {
        CharacterRuntimeState(equipment: equipment)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
