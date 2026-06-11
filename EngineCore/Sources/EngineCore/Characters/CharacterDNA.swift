public enum CharacterRole: String, CaseIterable, Codable, Sendable {
    case player
    case settler
    case explorer
}

public struct CharacterIdentity: Equatable, Hashable, Codable, Sendable {
    public let displayName: String
    public let role: CharacterRole
    public let cultureSeed: UInt64
    public let apparentAge: Float

    public init(
        displayName: String,
        role: CharacterRole,
        cultureSeed: UInt64,
        apparentAge: Float
    ) {
        precondition(!displayName.isEmpty, "Character displayName cannot be empty.")

        self.displayName = displayName
        self.role = role
        self.cultureSeed = cultureSeed
        self.apparentAge = min(max(apparentAge, 0), 1)
    }
}

public struct CharacterDNA: Equatable, Hashable, Codable, Sendable {
    public static let currentSchemaVersion: UInt32 = 1

    public let schemaVersion: UInt32
    public let id: StableID
    public let worldSeed: WorldSeed
    public let characterSeed: UInt64
    public let factionSeed: UInt64
    public let familySeed: UInt64
    public let lifeHistorySeed: UInt64
    public let identity: CharacterIdentity
    public let body: CharacterBodyParameters
    public let appearance: CharacterAppearance
    public let equipment: CharacterEquipmentSet
    public let lodPolicy: CharacterLODPolicy
    public let meshDescriptor: CharacterMeshDescriptor

    public init(
        schemaVersion: UInt32 = Self.currentSchemaVersion,
        id: StableID,
        worldSeed: WorldSeed,
        characterSeed: UInt64,
        factionSeed: UInt64,
        familySeed: UInt64,
        lifeHistorySeed: UInt64,
        identity: CharacterIdentity,
        body: CharacterBodyParameters,
        appearance: CharacterAppearance,
        equipment: CharacterEquipmentSet,
        lodPolicy: CharacterLODPolicy = CharacterLODPolicy(),
        meshDescriptor: CharacterMeshDescriptor? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.worldSeed = worldSeed
        self.characterSeed = characterSeed
        self.factionSeed = factionSeed
        self.familySeed = familySeed
        self.lifeHistorySeed = lifeHistorySeed
        self.identity = identity
        self.body = body
        self.appearance = appearance
        self.equipment = equipment
        self.lodPolicy = lodPolicy
        self.meshDescriptor = meshDescriptor ?? CharacterMeshDescriptor.simpleHumanoid(
            body: body,
            appearance: appearance,
            equipment: equipment
        )
    }

    public var skeleton: CharacterHumanoidSkeleton {
        body.skeleton
    }

    public var sockets: [CharacterSocketDefinition] {
        body.sockets
    }

    public var defaultRuntimeState: CharacterRuntimeState {
        CharacterRuntimeState.initial(equipment: equipment)
    }

    public static func makePlayer(
        worldSeed: WorldSeed,
        characterIndex: Int = 0,
        generatorVersions: GeneratorVersionTable = .current
    ) -> CharacterDNA {
        precondition(characterIndex >= 0, "characterIndex must be non-negative.")

        let context = GenerationContext(
            worldSeed: worldSeed,
            generatorVersions: generatorVersions,
            domain: .characters
        )
        let indexValue = UInt64(characterIndex)
        var random = context.rng(values: [indexValue])
        let id = context.stableID(values: [indexValue])
        let characterSeed = random.next()
        let factionSeed = random.next()
        let familySeed = random.next()
        let lifeHistorySeed = random.next()
        let body = CharacterBodyParameters.makePlayerBody(random: &random)
        let appearance = CharacterAppearance.makePlayerAppearance(random: &random)
        let equipment = CharacterEquipmentSet.starterOutfit(
            worldSeed: worldSeed,
            characterID: id,
            random: &random
        )
        let lodPolicy = CharacterLODPolicy(
            highDetailDistance: 6,
            mediumDetailDistance: 18,
            lowDetailDistance: 42,
            impostorDistance: 90
        )

        return CharacterDNA(
            id: id,
            worldSeed: worldSeed,
            characterSeed: characterSeed,
            factionSeed: factionSeed,
            familySeed: familySeed,
            lifeHistorySeed: lifeHistorySeed,
            identity: CharacterIdentity(
                displayName: characterIndex == 0 ? "Player" : "Player \(characterIndex + 1)",
                role: .player,
                cultureSeed: random.next(),
                apparentAge: random.nextFloat(in: 0.24...0.58)
            ),
            body: body,
            appearance: appearance,
            equipment: equipment,
            lodPolicy: lodPolicy
        )
    }
}
