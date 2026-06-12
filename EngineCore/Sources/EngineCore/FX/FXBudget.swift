public struct FXBudget: Equatable, Hashable, Codable, Sendable {
    public let maxEventsPerFrame: Int
    public let maxParticlesPerFrame: Int
    public let maxDecalsPerFrame: Int
    public let maxParticlesPerBurst: Int

    public init(
        maxEventsPerFrame: Int,
        maxParticlesPerFrame: Int,
        maxDecalsPerFrame: Int,
        maxParticlesPerBurst: Int
    ) {
        self.maxEventsPerFrame = max(maxEventsPerFrame, 0)
        self.maxParticlesPerFrame = max(maxParticlesPerFrame, 0)
        self.maxDecalsPerFrame = max(maxDecalsPerFrame, 0)
        self.maxParticlesPerBurst = max(maxParticlesPerBurst, 0)
    }

    public static let v1Realtime = FXBudget(
        maxEventsPerFrame: 32,
        maxParticlesPerFrame: 96,
        maxDecalsPerFrame: 32,
        maxParticlesPerBurst: 12
    )

    public static let strictDebug = FXBudget(
        maxEventsPerFrame: 12,
        maxParticlesPerFrame: 32,
        maxDecalsPerFrame: 12,
        maxParticlesPerBurst: 8
    )

    public func apply(
        events: [FXEvent],
        particles: [FXBillboardParticle],
        decals: [FXDecal]
    ) -> FXBudgetedFrame {
        let keptEvents = Array(events.prefix(maxEventsPerFrame))
        let keptParticles = Array(
            particles
                .sorted { lhs, rhs in lhs.age < rhs.age }
                .prefix(maxParticlesPerFrame)
        )
        let keptDecals = Array(
            decals
                .sorted { lhs, rhs in lhs.age < rhs.age }
                .prefix(maxDecalsPerFrame)
        )

        return FXBudgetedFrame(
            events: keptEvents,
            particles: keptParticles,
            decals: keptDecals,
            result: FXBudgetResult(
                eventCount: keptEvents.count,
                particleCount: keptParticles.count,
                decalCount: keptDecals.count,
                droppedEvents: max(events.count - keptEvents.count, 0),
                droppedParticles: max(particles.count - keptParticles.count, 0),
                droppedDecals: max(decals.count - keptDecals.count, 0)
            )
        )
    }
}

public struct FXBudgetResult: Equatable, Hashable, Codable, Sendable {
    public static let empty = FXBudgetResult(
        eventCount: 0,
        particleCount: 0,
        decalCount: 0,
        droppedEvents: 0,
        droppedParticles: 0,
        droppedDecals: 0
    )

    public let eventCount: Int
    public let particleCount: Int
    public let decalCount: Int
    public let droppedEvents: Int
    public let droppedParticles: Int
    public let droppedDecals: Int

    public init(
        eventCount: Int,
        particleCount: Int,
        decalCount: Int,
        droppedEvents: Int,
        droppedParticles: Int,
        droppedDecals: Int
    ) {
        self.eventCount = max(eventCount, 0)
        self.particleCount = max(particleCount, 0)
        self.decalCount = max(decalCount, 0)
        self.droppedEvents = max(droppedEvents, 0)
        self.droppedParticles = max(droppedParticles, 0)
        self.droppedDecals = max(droppedDecals, 0)
    }
}

public struct FXBudgetedFrame: Equatable, Codable, Sendable {
    public let events: [FXEvent]
    public let particles: [FXBillboardParticle]
    public let decals: [FXDecal]
    public let result: FXBudgetResult

    public init(
        events: [FXEvent],
        particles: [FXBillboardParticle],
        decals: [FXDecal],
        result: FXBudgetResult
    ) {
        self.events = events
        self.particles = particles
        self.decals = decals
        self.result = result
    }
}
