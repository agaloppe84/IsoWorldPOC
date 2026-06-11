public enum EquipmentLayer: Int, CaseIterable, Codable, Sendable {
    case base
    case clothing
    case armor
    case accessory
    case held
}

public enum CharacterSocketID: String, CaseIterable, Codable, Sendable {
    case head
    case chest
    case back
    case belt
    case leftHand
    case rightHand
    case leftFoot
    case rightFoot
}

public enum EquipmentSlot: String, CaseIterable, Codable, Sendable {
    case hair
    case head
    case face
    case torso
    case hands
    case legs
    case feet
    case back
    case belt
    case leftHand
    case rightHand
    case accessory

    public var layer: EquipmentLayer {
        switch self {
        case .hair:
            return .base
        case .head, .face, .torso, .hands, .legs, .feet:
            return .clothing
        case .back, .belt, .accessory:
            return .accessory
        case .leftHand, .rightHand:
            return .held
        }
    }

    public var socketID: CharacterSocketID? {
        switch self {
        case .hair, .head, .face:
            return .head
        case .torso:
            return .chest
        case .hands:
            return nil
        case .legs:
            return .belt
        case .feet:
            return nil
        case .back:
            return .back
        case .belt, .accessory:
            return .belt
        case .leftHand:
            return .leftHand
        case .rightHand:
            return .rightHand
        }
    }

    public var blocksBodyMorph: Bool {
        switch layer {
        case .armor:
            return true
        case .base, .clothing, .accessory, .held:
            return false
        }
    }
}

public struct CharacterSocketDefinition: Equatable, Hashable, Codable, Sendable {
    public let id: CharacterSocketID
    public let jointID: CharacterJointID
    public let localX: Float
    public let localY: Float
    public let localZ: Float
    public let allowedSlots: [EquipmentSlot]

    public init(
        id: CharacterSocketID,
        jointID: CharacterJointID,
        localX: Float,
        localY: Float,
        localZ: Float,
        allowedSlots: [EquipmentSlot]
    ) {
        self.id = id
        self.jointID = jointID
        self.localX = localX
        self.localY = localY
        self.localZ = localZ
        self.allowedSlots = allowedSlots
    }

    public static func canonical(body: CharacterBodyParameters) -> [CharacterSocketDefinition] {
        [
            CharacterSocketDefinition(
                id: .head,
                jointID: .head,
                localX: 0,
                localY: body.headScale * 0.12,
                localZ: 0,
                allowedSlots: [.hair, .head, .face]
            ),
            CharacterSocketDefinition(
                id: .chest,
                jointID: .chest,
                localX: 0,
                localY: 0,
                localZ: body.chestDepth * 0.5,
                allowedSlots: [.torso]
            ),
            CharacterSocketDefinition(
                id: .back,
                jointID: .chest,
                localX: 0,
                localY: 0.04,
                localZ: -body.chestDepth * 0.68,
                allowedSlots: [.back]
            ),
            CharacterSocketDefinition(
                id: .belt,
                jointID: .hips,
                localX: 0,
                localY: 0,
                localZ: body.chestDepth * 0.25,
                allowedSlots: [.legs, .belt, .accessory]
            ),
            CharacterSocketDefinition(
                id: .leftHand,
                jointID: .leftHand,
                localX: 0,
                localY: 0,
                localZ: 0,
                allowedSlots: [.leftHand]
            ),
            CharacterSocketDefinition(
                id: .rightHand,
                jointID: .rightHand,
                localX: 0,
                localY: 0,
                localZ: 0,
                allowedSlots: [.rightHand]
            ),
            CharacterSocketDefinition(
                id: .leftFoot,
                jointID: .leftFoot,
                localX: 0,
                localY: 0,
                localZ: 0.04,
                allowedSlots: [.feet]
            ),
            CharacterSocketDefinition(
                id: .rightFoot,
                jointID: .rightFoot,
                localX: 0,
                localY: 0,
                localZ: 0.04,
                allowedSlots: [.feet]
            ),
        ]
    }
}
