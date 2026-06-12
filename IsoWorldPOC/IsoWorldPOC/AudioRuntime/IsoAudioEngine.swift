//
//  IsoAudioEngine.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore

struct AudioRuntimeSnapshot: Equatable {
    static let empty = AudioRuntimeSnapshot(
        queuedEventCount: 0,
        processedEventCount: 0,
        droppedEventCount: 0,
        totalProcessedEventCount: 0,
        activeVoiceCount: 0,
        peak: 0,
        rms: 0,
        busMeters: [],
        recentEvents: []
    )

    let queuedEventCount: Int
    let processedEventCount: Int
    let droppedEventCount: Int
    let totalProcessedEventCount: Int
    let activeVoiceCount: Int
    let peak: Float
    let rms: Float
    let busMeters: [AudioBusMeter]
    let recentEvents: [IsoAudioEvent]
}

final class IsoAudioEngine {
    let eventQueue: AudioEventQueue
    let samplePlayer: SamplePlayer
    let noiseSynth: NoiseSynth

    private let recipesByID: [AudioRecipeID: AudioRecipe]
    private let mixState: AudioMixState
    private(set) var snapshot = AudioRuntimeSnapshot.empty
    private var totalProcessedEventCount = 0

    init(
        recipes: [AudioRecipe] = AudioRecipe.v1Recipes,
        mixState: AudioMixState = AudioMixState(),
        eventQueue: AudioEventQueue = AudioEventQueue(),
        samplePlayer: SamplePlayer = SamplePlayer(),
        noiseSynth: NoiseSynth = NoiseSynth()
    ) {
        self.recipesByID = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
        self.mixState = mixState
        self.eventQueue = eventQueue
        self.samplePlayer = samplePlayer
        self.noiseSynth = noiseSynth
    }

    func post(_ event: IsoAudioEvent) {
        eventQueue.enqueue(event)
    }

    func post(contentsOf events: [IsoAudioEvent]) {
        eventQueue.enqueue(contentsOf: events)
    }

    @discardableResult
    func update(maxEventsPerFrame: Int = 32) -> AudioRuntimeSnapshot {
        let events = eventQueue.drain(maxCount: maxEventsPerFrame)
        let renderedBuffers = events.compactMap(render)
        let busMeters = makeBusMeters(
            renderedBuffers: renderedBuffers,
            processedEvents: events
        )
        let peak = renderedBuffers.reduce(Float(0)) { max($0, $1.peak) }
        let rms = mixedRMS(renderedBuffers)

        totalProcessedEventCount += events.count
        snapshot = AudioRuntimeSnapshot(
            queuedEventCount: eventQueue.pendingEventCount,
            processedEventCount: events.count,
            droppedEventCount: eventQueue.droppedEventCount,
            totalProcessedEventCount: totalProcessedEventCount,
            activeVoiceCount: renderedBuffers.count,
            peak: min(max(peak, 0), 1),
            rms: min(max(rms, 0), 1),
            busMeters: busMeters,
            recentEvents: Array(events.prefix(8))
        )

        return snapshot
    }

    private func render(_ event: IsoAudioEvent) -> AudioRenderedBuffer? {
        guard let recipe = recipesByID[event.recipeID] else {
            return nil
        }

        let rendered: AudioRenderedBuffer
        switch recipe.renderer {
        case .samplePlayer:
            rendered = samplePlayer.render(event: event, recipe: recipe)
        case .noiseSynth:
            rendered = noiseSynth.render(event: event, recipe: recipe)
        case .hybrid:
            rendered = mix(
                samplePlayer.render(event: event, recipe: recipe),
                noiseSynth.render(event: event, recipe: recipe)
            )
        }

        let busGain = mixState.effectiveGain(for: event.bus)
        guard busGain > 0 else {
            return AudioRenderedBuffer(
                bus: event.bus,
                sampleRate: rendered.sampleRate,
                samples: Array(repeating: 0, count: rendered.samples.count)
            )
        }

        return AudioRenderedBuffer(
            bus: event.bus,
            sampleRate: rendered.sampleRate,
            samples: rendered.samples.map { min(max($0 * busGain, -1), 1) }
        )
    }

    private func mix(
        _ lhs: AudioRenderedBuffer,
        _ rhs: AudioRenderedBuffer
    ) -> AudioRenderedBuffer {
        let count = max(lhs.samples.count, rhs.samples.count)
        let samples = (0..<count).map { index -> Float in
            let lhsSample = index < lhs.samples.count ? lhs.samples[index] : 0
            let rhsSample = index < rhs.samples.count ? rhs.samples[index] : 0
            return min(max(lhsSample * 0.58 + rhsSample * 0.42, -1), 1)
        }

        return AudioRenderedBuffer(
            bus: lhs.bus,
            sampleRate: lhs.sampleRate,
            samples: samples
        )
    }

    private func makeBusMeters(
        renderedBuffers: [AudioRenderedBuffer],
        processedEvents: [IsoAudioEvent]
    ) -> [AudioBusMeter] {
        AudioBusID.allCases.compactMap { bus in
            let busBuffers = renderedBuffers.filter { $0.bus == bus }
            let busEvents = processedEvents.filter { $0.bus == bus }

            guard !busBuffers.isEmpty || !busEvents.isEmpty else {
                return nil
            }

            return AudioBusMeter(
                bus: bus,
                peak: busBuffers.reduce(Float(0)) { max($0, $1.peak) },
                rms: mixedRMS(busBuffers),
                activeVoiceCount: busBuffers.count,
                processedEventCount: busEvents.count
            )
        }
    }

    private func mixedRMS(_ buffers: [AudioRenderedBuffer]) -> Float {
        let sampleCount = buffers.reduce(0) { $0 + $1.samples.count }

        guard sampleCount > 0 else {
            return 0
        }

        let energy = buffers.reduce(Float(0)) { total, buffer in
            total + buffer.samples.reduce(Float(0)) { $0 + $1 * $1 }
        }

        return (energy / Float(sampleCount)).squareRoot()
    }
}
