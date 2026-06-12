public enum AudioBusID: String, CaseIterable, Codable, Sendable {
    case master
    case music
    case ambience
    case foley
    case world
    case ui

    public var parent: AudioBusID? {
        switch self {
        case .master:
            nil
        case .music, .ambience, .foley, .world, .ui:
            .master
        }
    }
}

public struct AudioBus: Equatable, Hashable, Codable, Sendable {
    public let id: AudioBusID
    public let gain: Float
    public let isMuted: Bool

    public init(
        id: AudioBusID,
        gain: Float = 1,
        isMuted: Bool = false
    ) {
        self.id = id
        self.gain = min(max(gain, 0), 2)
        self.isMuted = isMuted
    }
}

public struct AudioMixState: Equatable, Hashable, Codable, Sendable {
    public let buses: [AudioBus]

    public init(buses: [AudioBus] = AudioBusID.allCases.map { AudioBus(id: $0) }) {
        var busesByID: [AudioBusID: AudioBus] = [:]

        for bus in buses {
            busesByID[bus.id] = bus
        }

        self.buses = AudioBusID.allCases.map { id in
            busesByID[id] ?? AudioBus(id: id)
        }
    }

    public func bus(_ id: AudioBusID) -> AudioBus {
        buses.first { $0.id == id } ?? AudioBus(id: id)
    }

    public func effectiveGain(for id: AudioBusID) -> Float {
        let bus = self.bus(id)

        guard !bus.isMuted else {
            return 0
        }

        if let parent = id.parent {
            return bus.gain * effectiveGain(for: parent)
        }

        return bus.gain
    }
}

public struct AudioBusMeter: Equatable, Hashable, Codable, Sendable {
    public let bus: AudioBusID
    public let peak: Float
    public let rms: Float
    public let activeVoiceCount: Int
    public let processedEventCount: Int

    public init(
        bus: AudioBusID,
        peak: Float,
        rms: Float,
        activeVoiceCount: Int,
        processedEventCount: Int
    ) {
        self.bus = bus
        self.peak = min(max(peak, 0), 1)
        self.rms = min(max(rms, 0), 1)
        self.activeVoiceCount = max(activeVoiceCount, 0)
        self.processedEventCount = max(processedEventCount, 0)
    }
}
