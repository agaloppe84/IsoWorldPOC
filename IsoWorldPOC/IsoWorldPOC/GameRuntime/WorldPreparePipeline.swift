import EngineCore

struct LoadingProgress: Equatable, Sendable {
    let seed: String
    let phase: String
    let progress: Double

    static func initial(seed: String) -> LoadingProgress {
        LoadingProgress(seed: seed, phase: "Seed", progress: 0)
    }
}

actor WorldPreparePipeline {
    private let jobScheduler = JobScheduler()

    func prepareWorld(
        seed: String,
        progress: @MainActor @Sendable (LoadingProgress) -> Void
    ) async throws -> WorldSession {
        try Task.checkCancellation()
        await progress(LoadingProgress(seed: seed, phase: "Seed", progress: 0.15))

        let worldSeed = worldSeed(from: seed)
        _ = WorldDNA.make(worldSeed: worldSeed)

        try Task.checkCancellation()
        await progress(LoadingProgress(seed: seed, phase: "World DNA", progress: 0.35))

        let handle = jobScheduler.submit(EngineJob<Void>(
            name: "prepare-initial-chunk",
            priority: .userInitiated
        ) { cancellationToken in
            _ = try ProceduralChunkDataFactory.makeChunkData(
                coordinate: .origin,
                cancellationToken: cancellationToken
            )
        })

        try await withTaskCancellationHandler {
            try await handle.value()
        } onCancel: {
            handle.cancel()
        }

        try Task.checkCancellation()
        await progress(LoadingProgress(seed: seed, phase: "Terrain bootstrap", progress: 0.60))
        await progress(LoadingProgress(seed: seed, phase: "Render payloads", progress: 0.82))
        await progress(LoadingProgress(seed: seed, phase: "Ready", progress: 1.0))

        return makeWorldSession(seed: seed)
    }

    func makeWorldSession(seed: String) -> WorldSession {
        WorldSession(seed: seed)
    }

    private func worldSeed(from seed: String) -> WorldSeed {
        WorldSeed(StableHash.make { builder in
            builder.combine(seed)
        }.value)
    }
}
