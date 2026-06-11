public enum CharacterCustomizationOverrideKind: String, CaseIterable, Codable, Sendable {
    case body
    case appearance
    case equipment
}

public struct CharacterCustomizationOverride: Equatable, Hashable, Codable, Sendable {
    public let kind: CharacterCustomizationOverrideKind
    public let identifier: String
    public let value: Float

    public init(
        kind: CharacterCustomizationOverrideKind,
        identifier: String,
        value: Float
    ) {
        precondition(!identifier.isEmpty, "Customization override identifier cannot be empty.")

        self.kind = kind
        self.identifier = identifier
        self.value = min(max(value, 0), 1)
    }
}

public struct CharacterCustomizationSave: Equatable, Hashable, Codable, Sendable {
    public static let currentSchemaVersion: UInt32 = 1

    public let schemaVersion: UInt32
    public let worldSeed: WorldSeed
    public let characterDNA: CharacterDNA
    public let runtimeState: CharacterRuntimeState
    public let overrides: [CharacterCustomizationOverride]
    public let validCacheIDs: [StableID]

    public init(
        schemaVersion: UInt32 = Self.currentSchemaVersion,
        worldSeed: WorldSeed,
        characterDNA: CharacterDNA,
        runtimeState: CharacterRuntimeState,
        overrides: [CharacterCustomizationOverride] = [],
        validCacheIDs: [StableID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.worldSeed = worldSeed
        self.characterDNA = characterDNA
        self.runtimeState = runtimeState
        self.overrides = overrides.sorted { $0.identifier < $1.identifier }
        self.validCacheIDs = validCacheIDs.sorted { $0.rawValue < $1.rawValue }
    }

    public var isRegenerable: Bool {
        schemaVersion == Self.currentSchemaVersion &&
            characterDNA.worldSeed == worldSeed &&
            characterDNA.schemaVersion == CharacterDNA.currentSchemaVersion
    }

    public func withRuntimeState(_ runtimeState: CharacterRuntimeState) -> CharacterCustomizationSave {
        CharacterCustomizationSave(
            schemaVersion: schemaVersion,
            worldSeed: worldSeed,
            characterDNA: characterDNA,
            runtimeState: runtimeState,
            overrides: overrides,
            validCacheIDs: validCacheIDs
        )
    }

    public static func defaultPlayer(worldSeed: WorldSeed) -> CharacterCustomizationSave {
        let dna = CharacterDNA.makePlayer(worldSeed: worldSeed)
        return CharacterCustomizationSave(
            worldSeed: worldSeed,
            characterDNA: dna,
            runtimeState: CharacterRuntimeState.initial(equipment: dna.equipment)
        )
    }
}
