public struct AudioRecipeID: RawRepresentable, Equatable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "AudioRecipeID cannot be empty.")
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.init(rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public enum IsoAudioEventKind: String, CaseIterable, Codable, Sendable {
    case footstep
    case impact
    case ambience
    case ui
}

public enum AudioPriority: Int, CaseIterable, Comparable, Codable, Sendable {
    case background = 0
    case ambience = 10
    case gameplay = 20
    case critical = 30

    public static func < (lhs: AudioPriority, rhs: AudioPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct AudioSeedContext: Equatable, Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let eventSeed: UInt64
    public let variationIndex: Int

    public init(
        worldSeed: WorldSeed,
        eventSeed: UInt64,
        variationIndex: Int = 0
    ) {
        self.worldSeed = worldSeed
        self.eventSeed = eventSeed
        self.variationIndex = max(variationIndex, 0)
    }
}

public struct IsoAudioEvent: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let sourceID: StableID
    public let kind: IsoAudioEventKind
    public let recipeID: AudioRecipeID
    public let bus: AudioBusID
    public let time: Float
    public let priority: AudioPriority
    public let position: WorldPosition?
    public let surface: AudioSurfaceInfo?
    public let seedContext: AudioSeedContext
    public let parameters: AudioParameterSet

    public init(
        id: StableID,
        sourceID: StableID,
        kind: IsoAudioEventKind,
        recipeID: AudioRecipeID,
        bus: AudioBusID,
        time: Float,
        priority: AudioPriority,
        position: WorldPosition? = nil,
        surface: AudioSurfaceInfo? = nil,
        seedContext: AudioSeedContext,
        parameters: AudioParameterSet = .empty
    ) {
        self.id = id
        self.sourceID = sourceID
        self.kind = kind
        self.recipeID = recipeID
        self.bus = bus
        self.time = max(time, 0)
        self.priority = priority
        self.position = position
        self.surface = surface
        self.seedContext = seedContext
        self.parameters = parameters
    }
}

public extension AudioRecipeID {
    static let ambienceOpenWorld: AudioRecipeID = "audio.ambience.open-world"

    static func footstep(for materialKind: TerrainMaterialKind) -> AudioRecipeID {
        switch materialKind {
        case .grass:
            "audio.footstep.grass"
        case .rock:
            "audio.footstep.rock"
        case .dirt:
            "audio.footstep.dirt"
        case .sand:
            "audio.footstep.sand"
        case .mud:
            "audio.footstep.mud"
        case .snow:
            "audio.footstep.snow"
        }
    }
}
