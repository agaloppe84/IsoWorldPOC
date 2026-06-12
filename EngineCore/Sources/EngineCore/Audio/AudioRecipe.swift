public enum AudioRecipeCategory: String, CaseIterable, Codable, Sendable {
    case locomotion
    case impact
    case ambience
    case ui
}

public enum AudioSourceRenderer: String, CaseIterable, Codable, Sendable {
    case samplePlayer
    case noiseSynth
    case hybrid
}

public struct AudioRecipe: Equatable, Hashable, Codable, Sendable {
    public let id: AudioRecipeID
    public let category: AudioRecipeCategory
    public let renderer: AudioSourceRenderer
    public let bus: AudioBusID
    public let baseGain: Float
    public let gainVariation: AudioFloatRange
    public let pitchVariationCents: AudioFloatRange
    public let durationSeconds: AudioFloatRange
    public let defaultParameters: AudioParameterSet

    public init(
        id: AudioRecipeID,
        category: AudioRecipeCategory,
        renderer: AudioSourceRenderer,
        bus: AudioBusID,
        baseGain: Float,
        gainVariation: AudioFloatRange,
        pitchVariationCents: AudioFloatRange,
        durationSeconds: AudioFloatRange,
        defaultParameters: AudioParameterSet = .empty
    ) {
        self.id = id
        self.category = category
        self.renderer = renderer
        self.bus = bus
        self.baseGain = min(max(baseGain, 0), 2)
        self.gainVariation = gainVariation
        self.pitchVariationCents = pitchVariationCents
        self.durationSeconds = durationSeconds
        self.defaultParameters = defaultParameters
    }
}

public extension AudioRecipe {
    static let openWorldAmbience = AudioRecipe(
        id: .ambienceOpenWorld,
        category: .ambience,
        renderer: .noiseSynth,
        bus: .ambience,
        baseGain: 0.18,
        gainVariation: AudioFloatRange(0.86, 1.08),
        pitchVariationCents: AudioFloatRange(-8, 8),
        durationSeconds: AudioFloatRange(1.0, 2.0),
        defaultParameters: AudioParameterSet(parameters: [
            AudioParameter(id: .surfaceRoughness, value: 0.35),
            AudioParameter(id: .surfaceSplash, value: 0),
        ])
    )

    static func footstep(for materialKind: TerrainMaterialKind) -> AudioRecipe {
        let response = AudioSurfaceResponse.response(
            for: materialKind,
            wetness: 0,
            friction: 0.5
        )

        switch materialKind {
        case .grass:
            return AudioRecipe(
                id: .footstep(for: .grass),
                category: .locomotion,
                renderer: .hybrid,
                bus: .foley,
                baseGain: 0.52,
                gainVariation: AudioFloatRange(0.86, 1.08),
                pitchVariationCents: AudioFloatRange(-45, 35),
                durationSeconds: AudioFloatRange(0.08, 0.14),
                defaultParameters: response.defaultParameters
            )
        case .rock:
            return AudioRecipe(
                id: .footstep(for: .rock),
                category: .locomotion,
                renderer: .samplePlayer,
                bus: .foley,
                baseGain: 0.64,
                gainVariation: AudioFloatRange(0.92, 1.16),
                pitchVariationCents: AudioFloatRange(-25, 70),
                durationSeconds: AudioFloatRange(0.045, 0.095),
                defaultParameters: response.defaultParameters
            )
        case .dirt:
            return AudioRecipe(
                id: .footstep(for: .dirt),
                category: .locomotion,
                renderer: .hybrid,
                bus: .foley,
                baseGain: 0.56,
                gainVariation: AudioFloatRange(0.86, 1.10),
                pitchVariationCents: AudioFloatRange(-35, 35),
                durationSeconds: AudioFloatRange(0.07, 0.13),
                defaultParameters: response.defaultParameters
            )
        case .sand:
            return AudioRecipe(
                id: .footstep(for: .sand),
                category: .locomotion,
                renderer: .noiseSynth,
                bus: .foley,
                baseGain: 0.46,
                gainVariation: AudioFloatRange(0.82, 1.04),
                pitchVariationCents: AudioFloatRange(-70, 15),
                durationSeconds: AudioFloatRange(0.10, 0.18),
                defaultParameters: response.defaultParameters
            )
        case .mud:
            return AudioRecipe(
                id: .footstep(for: .mud),
                category: .locomotion,
                renderer: .hybrid,
                bus: .foley,
                baseGain: 0.58,
                gainVariation: AudioFloatRange(0.90, 1.18),
                pitchVariationCents: AudioFloatRange(-110, -20),
                durationSeconds: AudioFloatRange(0.12, 0.22),
                defaultParameters: response.defaultParameters
            )
        case .snow:
            return AudioRecipe(
                id: .footstep(for: .snow),
                category: .locomotion,
                renderer: .noiseSynth,
                bus: .foley,
                baseGain: 0.50,
                gainVariation: AudioFloatRange(0.82, 1.08),
                pitchVariationCents: AudioFloatRange(-85, 10),
                durationSeconds: AudioFloatRange(0.10, 0.18),
                defaultParameters: response.defaultParameters
            )
        }
    }

    static let v1Recipes: [AudioRecipe] = [openWorldAmbience] +
        TerrainMaterialKind.allCases.map { AudioRecipe.footstep(for: $0) }
}

public extension AudioSurfaceResponse {
    var defaultParameters: AudioParameterSet {
        AudioParameterSet(parameters: [
            AudioParameter(id: .surfaceHardness, value: hardness),
            AudioParameter(id: .surfaceRoughness, value: roughness),
            AudioParameter(id: .surfacePorosity, value: porosity),
            AudioParameter(id: .surfaceCrunch, value: crunch),
            AudioParameter(id: .surfaceSplash, value: splash),
            AudioParameter(id: .surfaceSquish, value: squish),
        ])
    }
}

public struct AudioRecipeResolver: Equatable, Sendable {
    public let recipes: [AudioRecipe]

    public init(recipes: [AudioRecipe] = AudioRecipe.v1Recipes) {
        self.recipes = recipes.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func recipe(for id: AudioRecipeID) -> AudioRecipe? {
        recipes.first { $0.id == id }
    }

    public func makeFootstepEvents(
        from footsteps: [FootstepEvent],
        context: AudioContext
    ) -> [IsoAudioEvent] {
        footsteps.compactMap { footstep in
            makeFootstepEvent(from: footstep, context: context)
        }
    }

    public func makeFootstepEvent(
        from footstep: FootstepEvent,
        context: AudioContext
    ) -> IsoAudioEvent? {
        let recipeID = AudioRecipeID.footstep(for: footstep.materialKind)

        guard let recipe = recipe(for: recipeID) else {
            return nil
        }

        let response = context.surfaceResponse(
            for: footstep.materialKind,
            wetness: footstep.wetness,
            friction: footstep.friction
        )
        let seed = context.seed(
            sourceID: footstep.id,
            recipeID: recipe.id,
            kind: .footstep
        )
        var rng = StableRNG(seedValue: seed)
        let position = WorldPosition(
            x: footstep.worldX,
            y: footstep.worldY,
            z: footstep.worldZ
        )
        let distance = context.distanceMeters(to: position)
        let duration = recipe.durationSeconds.sample(rng.nextUnitFloat())
        let pitch = recipe.pitchVariationCents.sample(rng.nextUnitFloat()) +
            response.pitchOffsetCents
        let gain = recipe.baseGain *
            recipe.gainVariation.sample(rng.nextUnitFloat()) *
            response.gainScale *
            min(max(footstep.intensity, 0), 1)
        let parameters = recipe.defaultParameters
            .merging(response.defaultParameters)
            .setting(.intensity, to: footstep.intensity)
            .setting(.wetness, to: footstep.wetness)
            .setting(.friction, to: footstep.friction)
            .setting(.gain, to: gain)
            .setting(.pitchCents, to: pitch)
            .setting(.durationSeconds, to: duration)
            .setting(.distanceMeters, to: distance)

        return IsoAudioEvent(
            id: StableID(seed),
            sourceID: footstep.id,
            kind: .footstep,
            recipeID: recipe.id,
            bus: recipe.bus,
            time: context.simulationTime,
            priority: .gameplay,
            position: position,
            surface: response.surfaceInfo(
                wetness: footstep.wetness,
                friction: footstep.friction
            ),
            seedContext: AudioSeedContext(
                worldSeed: context.worldSeed,
                eventSeed: seed
            ),
            parameters: parameters
        )
    }
}
