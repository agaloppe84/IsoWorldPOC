import Foundation

public struct PlayerProfile: Hashable, Codable, Sendable {
    public static let defaultRecentSeedLimit = 10

    public let id: StableID
    public let displayName: String
    public let recentSeeds: [String]
    public let lastOpenedSlotID: SaveSlotID?
    public let appPreferences: AppPreferences
    public let characterCustomization: CharacterCustomizationSave?

    public init(
        id: StableID = StableID(0),
        displayName: String = "Player",
        recentSeeds: [String] = [],
        lastOpenedSlotID: SaveSlotID? = nil,
        appPreferences: AppPreferences = AppPreferences(),
        characterCustomization: CharacterCustomizationSave? = nil
    ) {
        precondition(!displayName.isEmpty, "displayName cannot be empty.")

        self.id = id
        self.displayName = displayName
        self.recentSeeds = Self.uniqueSeeds(recentSeeds, limit: Self.defaultRecentSeedLimit)
        self.lastOpenedSlotID = lastOpenedSlotID
        self.appPreferences = appPreferences
        self.characterCustomization = characterCustomization
    }

    public func recordingRecentSeed(
        _ seed: String,
        limit: Int = Self.defaultRecentSeedLimit
    ) -> PlayerProfile {
        precondition(limit > 0, "limit must be positive.")

        let trimmedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSeed.isEmpty else {
            return self
        }

        return PlayerProfile(
            id: id,
            displayName: displayName,
            recentSeeds: Self.uniqueSeeds([trimmedSeed] + recentSeeds, limit: limit),
            lastOpenedSlotID: lastOpenedSlotID,
            appPreferences: appPreferences,
            characterCustomization: characterCustomization
        )
    }

    public func opening(slotID: SaveSlotID) -> PlayerProfile {
        PlayerProfile(
            id: id,
            displayName: displayName,
            recentSeeds: recentSeeds,
            lastOpenedSlotID: slotID,
            appPreferences: appPreferences,
            characterCustomization: characterCustomization
        )
    }

    public func withCharacterCustomization(_ customization: CharacterCustomizationSave) -> PlayerProfile {
        PlayerProfile(
            id: id,
            displayName: displayName,
            recentSeeds: recentSeeds,
            lastOpenedSlotID: lastOpenedSlotID,
            appPreferences: appPreferences,
            characterCustomization: customization
        )
    }

    private static func uniqueSeeds(_ seeds: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(min(seeds.count, limit))

        for seed in seeds {
            let trimmedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSeed.isEmpty, !seen.contains(trimmedSeed), result.count < limit else {
                continue
            }

            seen.insert(trimmedSeed)
            result.append(trimmedSeed)
        }

        return result
    }
}

public struct AppPreferences: Hashable, Codable, Sendable {
    public let preferredLocaleIdentifier: String?
    public let lastOpenedMode: String?
    public let debugPreferences: DebugPreferences

    public init(
        preferredLocaleIdentifier: String? = nil,
        lastOpenedMode: String? = nil,
        debugPreferences: DebugPreferences = DebugPreferences()
    ) {
        self.preferredLocaleIdentifier = preferredLocaleIdentifier
        self.lastOpenedMode = lastOpenedMode
        self.debugPreferences = debugPreferences
    }
}

public struct DebugPreferences: Hashable, Codable, Sendable {
    public let runMode: String
    public let renderOnlyWhenDirty: Bool
    public let showChunkBounds: Bool

    public init(
        runMode: String = "slowInspection",
        renderOnlyWhenDirty: Bool = true,
        showChunkBounds: Bool = true
    ) {
        precondition(!runMode.isEmpty, "runMode cannot be empty.")

        self.runMode = runMode
        self.renderOnlyWhenDirty = renderOnlyWhenDirty
        self.showChunkBounds = showChunkBounds
    }
}
