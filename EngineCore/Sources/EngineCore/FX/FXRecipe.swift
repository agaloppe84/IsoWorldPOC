import simd

public struct FXRecipe: Equatable, Sendable {
    public let definitions: [FXDefinitionID: FXDefinition]

    public init(definitions: [FXDefinition] = FXDefinition.v1Definitions) {
        var definitionsByID: [FXDefinitionID: FXDefinition] = [:]

        for definition in definitions {
            definitionsByID[definition.id] = definition
        }

        self.definitions = definitionsByID
    }

    public func makeFootstepFX(
        from footsteps: [FootstepEvent],
        context: FXContext,
        budget: FXBudget = .v1Realtime
    ) -> FXFrameSnapshot {
        var events: [FXEvent] = []
        var particles: [FXBillboardParticle] = []
        var decals: [FXDecal] = []

        for footstep in footsteps {
            let response = context.surfaceResponse(
                for: footstep.materialKind,
                wetness: footstep.wetness,
                friction: footstep.friction
            )
            let contactPosition = footstep.position + SIMD3<Float>(0, 0.03, 0)
            let contactNormal = SIMD3<Float>(0, 1, 0)

            if let event = contactEvent(
                kind: particleEventKind(for: footstep, response: response),
                sourceID: footstep.id,
                time: context.simulationTime,
                position: contactPosition,
                normal: contactNormal,
                materialKind: footstep.materialKind,
                intensity: particleIntensity(for: footstep, response: response),
                context: context
            ) {
                events.append(event)
                particles.append(contentsOf: spawnParticles(
                    event: event,
                    response: response,
                    budget: budget
                ))
            }

            if footstep.kind == .heelStrike || footstep.kind == .slide {
                let decalIntensity = footstep.intensity * response.footprintDecalStrength
                if decalIntensity > 0.04,
                   let event = contactEvent(
                    kind: .footprintDecal,
                    sourceID: footstep.id,
                    time: context.simulationTime,
                    position: contactPosition,
                    normal: contactNormal,
                    materialKind: footstep.materialKind,
                    intensity: decalIntensity,
                    context: context
                   ),
                   let decal = spawnDecal(event: event, response: response) {
                    events.append(event)
                    decals.append(decal)
                }
            }
        }

        let budgeted = budget.apply(
            events: events,
            particles: particles,
            decals: decals
        )

        return FXFrameSnapshot(
            events: budgeted.events,
            particles: budgeted.particles,
            decals: budgeted.decals,
            budget: budgeted.result
        )
    }

    public func makeImpactFX(
        sourceID: StableID,
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        materialKind: TerrainMaterialKind,
        intensity: Float,
        context: FXContext,
        budget: FXBudget = .v1Realtime
    ) -> FXFrameSnapshot {
        let response = context.surfaceResponse(
            for: materialKind,
            wetness: 0,
            friction: responseFriction(for: materialKind)
        )
        let eventIntensity = min(max(intensity, 0), 1)
        let probability = min(
            max(response.impactSparkChance * eventIntensity, materialKind == .rock && eventIntensity > 0.85 ? 1 : 0),
            1
        )
        let seed = eventSeed(
            worldSeed: context.worldSeed,
            sourceID: sourceID,
            kind: .impactSparks,
            materialKind: materialKind
        )
        var random = StableRNG(seedValue: seed)

        guard probability > 0, random.nextBool(probability: probability),
              let event = contactEvent(
                kind: .impactSparks,
                sourceID: sourceID,
                time: context.simulationTime,
                position: position,
                normal: normal,
                materialKind: materialKind,
                intensity: eventIntensity,
                context: context
              )
        else {
            return .empty
        }

        let particles = spawnParticles(
            event: event,
            response: response,
            budget: budget
        )
        let budgeted = budget.apply(events: [event], particles: particles, decals: [])

        return FXFrameSnapshot(
            events: budgeted.events,
            particles: budgeted.particles,
            decals: budgeted.decals,
            budget: budgeted.result
        )
    }

    private func particleEventKind(
        for footstep: FootstepEvent,
        response: FXSurfaceResponse
    ) -> FXEventKind? {
        let splashScore = footstep.wetness * response.splashMultiplier * response.wetnessSplashMultiplier
        let dustScore = (1 - footstep.wetness) * response.dustMultiplier

        if splashScore > max(0.18, dustScore * 0.80) {
            return .footstepSplash
        }

        if dustScore > 0.08 {
            return .footstepDust
        }

        return nil
    }

    private func particleIntensity(
        for footstep: FootstepEvent,
        response: FXSurfaceResponse
    ) -> Float {
        switch particleEventKind(for: footstep, response: response) {
        case .footstepSplash:
            return min(footstep.intensity * max(response.splashMultiplier, 0.25), 1)
        case .footstepDust:
            return min(footstep.intensity * max(response.dustMultiplier, 0.15), 1)
        case .impactSparks, .footprintDecal, .none:
            return footstep.intensity
        }
    }

    private func contactEvent(
        kind: FXEventKind?,
        sourceID: StableID,
        time: Float,
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        materialKind: TerrainMaterialKind,
        intensity: Float,
        context: FXContext
    ) -> FXEvent? {
        guard let kind, let definition = definition(for: kind), intensity > 0 else {
            return nil
        }

        let seed = eventSeed(
            worldSeed: context.worldSeed,
            sourceID: sourceID,
            kind: kind,
            materialKind: materialKind
        )
        let id = StableID(seed)

        return FXEvent(
            id: id,
            sourceID: sourceID,
            kind: kind,
            definitionID: definition.id,
            time: time,
            position: position,
            normal: normal,
            materialKind: materialKind,
            intensity: intensity,
            seed: seed
        )
    }

    private func spawnParticles(
        event: FXEvent,
        response: FXSurfaceResponse,
        budget: FXBudget
    ) -> [FXBillboardParticle] {
        guard let definition = definitions[event.definitionID], definition.kind == .billboardSprite else {
            return []
        }

        var random = StableRNG(seedValue: event.seed)
        let rawBurstCount = definition.burstCount.sample(random.nextUnitFloat())
        let count = min(
            max(Int((Float(rawBurstCount) * max(event.intensity, 0.15)).rounded()), 1),
            budget.maxParticlesPerBurst
        )
        let tint = particleTint(for: event.kind, response: response)
        let normal = event.normal

        return (0..<count).map { index in
            let particleSeed = childSeed(event.seed, salt: UInt64(index + 1))
            var particleRandom = StableRNG(seedValue: particleSeed)
            let angle = particleRandom.nextFloat(in: 0...(Float.pi * 2))
            let radial = SIMD3<Float>(cos(angle), 0, sin(angle))
            let speed = definition.initialSpeed.sample(particleRandom.nextUnitFloat())
            let upward = definition.upwardVelocity.sample(particleRandom.nextUnitFloat())
            let jitter = radial * particleRandom.nextFloat(in: 0.01...0.08)
            let lifetime = definition.lifetimeSeconds.sample(particleRandom.nextUnitFloat())
            let sizeScale = (0.70 + event.intensity * 0.65) * response.debrisSizeScale
            let baseSize = definition.startSize.sample(particleRandom.nextUnitFloat()) * sizeScale
            let startColor = definition.colorOverLife.sample(progress: 0).tinted(by: tint)
            let endColor = definition.colorOverLife.sample(progress: 1).tinted(by: tint)
            let startSize = baseSize * definition.sizeOverLife.sample(progress: 0)
            let endSize = baseSize * definition.sizeOverLife.sample(progress: 1)

            return FXBillboardParticle(
                id: StableID(particleSeed),
                definitionID: definition.id,
                materialKind: event.materialKind,
                position: event.position + jitter,
                velocity: radial * speed + normal * upward,
                startColor: startColor,
                endColor: endColor,
                startSize: startSize,
                endSize: endSize,
                lifetime: lifetime,
                gravity: definition.gravity,
                seed: particleSeed
            )
        }
    }

    private func spawnDecal(
        event: FXEvent,
        response: FXSurfaceResponse
    ) -> FXDecal? {
        guard let definition = definitions[event.definitionID], definition.kind == .decal else {
            return nil
        }

        var random = StableRNG(seedValue: event.seed)
        let lifetime = definition.lifetimeSeconds.sample(random.nextUnitFloat())
        let radius = definition.startSize.sample(random.nextUnitFloat()) *
            (0.80 + event.intensity * 0.45) *
            response.debrisSizeScale

        return FXDecal(
            id: StableID(childSeed(event.seed, salt: 1)),
            definitionID: definition.id,
            materialKind: event.materialKind,
            position: event.position + event.normal * 0.012,
            normal: event.normal,
            color: response.decalColor,
            radius: radius,
            opacity: event.intensity,
            rotationRadians: random.nextFloat(in: 0...(Float.pi * 2)),
            lifetime: lifetime,
            seed: event.seed
        )
    }

    private func definition(for kind: FXEventKind) -> FXDefinition? {
        switch kind {
        case .footstepDust:
            definitions[.footstepDust]
        case .footstepSplash:
            definitions[.footstepSplash]
        case .impactSparks:
            definitions[.impactSparks]
        case .footprintDecal:
            definitions[.footprintDecal]
        }
    }

    private func particleTint(
        for kind: FXEventKind,
        response: FXSurfaceResponse
    ) -> FXColor {
        switch kind {
        case .footstepDust:
            response.dustColor
        case .footstepSplash:
            response.splashColor
        case .impactSparks:
            response.sparkColor
        case .footprintDecal:
            response.decalColor
        }
    }

    private func eventSeed(
        worldSeed: WorldSeed,
        sourceID: StableID,
        kind: FXEventKind,
        materialKind: TerrainMaterialKind
    ) -> UInt64 {
        StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.fx)
            builder.combine(sourceID.rawValue)
            builder.combine(kind.rawValue)
            builder.combine(materialKind.rawValue)
        }.value
    }

    private func childSeed(_ seed: UInt64, salt: UInt64) -> UInt64 {
        StableHash.make { builder in
            builder.combine(seed)
            builder.combine(salt)
        }.value
    }

    private func responseFriction(for materialKind: TerrainMaterialKind) -> Float {
        switch materialKind {
        case .grass:
            0.62
        case .rock:
            0.78
        case .dirt:
            0.58
        case .sand:
            0.50
        case .mud:
            0.24
        case .snow:
            0.38
        }
    }
}
