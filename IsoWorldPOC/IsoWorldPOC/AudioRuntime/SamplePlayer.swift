//
//  SamplePlayer.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore
import Foundation

struct AudioRenderedBuffer: Equatable {
    let bus: AudioBusID
    let sampleRate: Int
    let samples: [Float]

    var durationSeconds: Float {
        guard sampleRate > 0 else {
            return 0
        }

        return Float(samples.count) / Float(sampleRate)
    }

    var peak: Float {
        samples.reduce(Float(0)) { max($0, abs($1)) }
    }

    var rms: Float {
        guard !samples.isEmpty else {
            return 0
        }

        let energy = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (energy / Float(samples.count)).squareRoot()
    }
}

struct AudioSampleAsset: Equatable {
    let id: String
    let recipeID: AudioRecipeID
    let sampleRate: Int
    let samples: [Float]
}

final class SamplePlayer {
    let sampleRate: Int

    private var assetsByRecipe: [AudioRecipeID: AudioSampleAsset]

    init(
        sampleRate: Int = 24_000,
        assets: [AudioSampleAsset] = []
    ) {
        self.sampleRate = max(sampleRate, 8_000)
        self.assetsByRecipe = Dictionary(uniqueKeysWithValues: assets.map { ($0.recipeID, $0) })
    }

    func register(_ asset: AudioSampleAsset) {
        assetsByRecipe[asset.recipeID] = asset
    }

    func render(
        event: IsoAudioEvent,
        recipe: AudioRecipe
    ) -> AudioRenderedBuffer {
        let duration = max(event.parameters.value(for: .durationSeconds, default: 0.08), 0.01)
        let gain = max(event.parameters.value(for: .gain, default: recipe.baseGain), 0)
        let sampleCount = max(Int(duration * Float(sampleRate)), 1)
        let sourceSamples = assetsByRecipe[recipe.id]?.samples ?? proceduralClick(
            event: event,
            recipe: recipe,
            sampleCount: sampleCount
        )

        let rendered = (0..<sampleCount).map { index -> Float in
            let source = sourceSamples[index % sourceSamples.count]
            let progress = Float(index) / Float(max(sampleCount - 1, 1))
            let envelope = exp(-progress * 7.0)
            return source * envelope * gain
        }

        return AudioRenderedBuffer(
            bus: event.bus,
            sampleRate: sampleRate,
            samples: rendered
        )
    }

    private func proceduralClick(
        event: IsoAudioEvent,
        recipe: AudioRecipe,
        sampleCount: Int
    ) -> [Float] {
        var rng = StableRNG(seedValue: event.seedContext.eventSeed)
        let hardness = event.parameters.value(for: .surfaceHardness, default: 0.5)
        let roughness = event.parameters.value(for: .surfaceRoughness, default: 0.5)
        let pitchCents = event.parameters.value(for: .pitchCents, default: 0)
        let baseFrequency = 120 + hardness * 560
        let pitchRatio = pow(2, pitchCents / 1_200)
        let frequency = baseFrequency * pitchRatio

        return (0..<sampleCount).map { index in
            let time = Float(index) / Float(sampleRate)
            let body = sin(time * frequency * 2 * Float.pi) * (0.25 + hardness * 0.45)
            let texture = (rng.nextUnitFloat() * 2 - 1) * roughness * 0.35
            return body + texture
        }
    }
}
