public struct AudioParameterID: RawRepresentable, Equatable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "AudioParameterID cannot be empty.")
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.init(rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public extension AudioParameterID {
    static let intensity: AudioParameterID = "audio.param.intensity"
    static let wetness: AudioParameterID = "audio.param.wetness"
    static let friction: AudioParameterID = "audio.param.friction"
    static let surfaceHardness: AudioParameterID = "audio.param.surfaceHardness"
    static let surfaceRoughness: AudioParameterID = "audio.param.surfaceRoughness"
    static let surfacePorosity: AudioParameterID = "audio.param.surfacePorosity"
    static let surfaceCrunch: AudioParameterID = "audio.param.surfaceCrunch"
    static let surfaceSplash: AudioParameterID = "audio.param.surfaceSplash"
    static let surfaceSquish: AudioParameterID = "audio.param.surfaceSquish"
    static let gain: AudioParameterID = "audio.param.gain"
    static let pitchCents: AudioParameterID = "audio.param.pitchCents"
    static let durationSeconds: AudioParameterID = "audio.param.durationSeconds"
    static let distanceMeters: AudioParameterID = "audio.param.distanceMeters"
}

public struct AudioParameter: Equatable, Hashable, Codable, Sendable {
    public let id: AudioParameterID
    public let value: Float

    public init(id: AudioParameterID, value: Float) {
        self.id = id
        self.value = value.isFinite ? value : 0
    }
}

public struct AudioParameterSet: Equatable, Hashable, Codable, Sendable {
    public static let empty = AudioParameterSet(parameters: [])

    public let parameters: [AudioParameter]

    public init(parameters: [AudioParameter]) {
        var valuesByID: [AudioParameterID: Float] = [:]

        for parameter in parameters {
            valuesByID[parameter.id] = parameter.value
        }

        self.parameters = valuesByID
            .map { AudioParameter(id: $0.key, value: $0.value) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func value(
        for id: AudioParameterID,
        default defaultValue: Float = 0
    ) -> Float {
        parameters.first { $0.id == id }?.value ?? defaultValue
    }

    public func setting(_ id: AudioParameterID, to value: Float) -> AudioParameterSet {
        AudioParameterSet(parameters: parameters + [AudioParameter(id: id, value: value)])
    }

    public func merging(_ other: AudioParameterSet) -> AudioParameterSet {
        AudioParameterSet(parameters: parameters + other.parameters)
    }
}

public struct AudioFloatRange: Equatable, Hashable, Codable, Sendable {
    public let lowerBound: Float
    public let upperBound: Float

    public init(_ lowerBound: Float, _ upperBound: Float) {
        self.lowerBound = min(lowerBound, upperBound)
        self.upperBound = max(lowerBound, upperBound)
    }

    public func sample(_ unitValue: Float) -> Float {
        lowerBound + (upperBound - lowerBound) * min(max(unitValue, 0), 1)
    }
}
