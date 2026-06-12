//
//  NoiseSynth.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore
import Foundation

final class NoiseSynth {
    let sampleRate: Int

    init(sampleRate: Int = 24_000) {
        self.sampleRate = max(sampleRate, 8_000)
    }

    func render(
        event: IsoAudioEvent,
        recipe: AudioRecipe
    ) -> AudioRenderedBuffer {
        let duration = max(event.parameters.value(for: .durationSeconds, default: 0.10), 0.01)
        let gain = max(event.parameters.value(for: .gain, default: recipe.baseGain), 0)
        let roughness = event.parameters.value(for: .surfaceRoughness, default: 0.5)
        let crunch = event.parameters.value(for: .surfaceCrunch, default: 0.2)
        let splash = event.parameters.value(for: .surfaceSplash, default: 0)
        let squish = event.parameters.value(for: .surfaceSquish, default: 0)
        let sampleCount = max(Int(duration * Float(sampleRate)), 1)
        var rng = StableRNG(seedValue: event.seedContext.eventSeed ^ 0xA0D1_0001)
        var previous: Float = 0

        let samples = (0..<sampleCount).map { index -> Float in
            let progress = Float(index) / Float(max(sampleCount - 1, 1))
            let attack = min(progress / 0.08, 1)
            let release = pow(max(1 - progress, 0), 1.8 + squish)
            let envelope = attack * release
            let white = rng.nextUnitFloat() * 2 - 1
            previous = previous * (0.18 + squish * 0.55) + white * (0.82 - squish * 0.35)
            let granular = white * roughness
            let wet = previous * (splash + squish) * 0.55
            let transient = (rng.nextBool(probability: min(crunch * 0.12, 0.45)) ? white : 0) * crunch

            return (granular * 0.55 + wet + transient * 0.35) * envelope * gain
        }

        return AudioRenderedBuffer(
            bus: event.bus,
            sampleRate: sampleRate,
            samples: samples
        )
    }
}
