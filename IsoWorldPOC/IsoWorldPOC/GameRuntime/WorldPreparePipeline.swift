struct LoadingProgress: Equatable {
    let seed: String
    let phase: String
    let progress: Double

    static func initial(seed: String) -> LoadingProgress {
        LoadingProgress(seed: seed, phase: "Seed", progress: 0)
    }
}

struct WorldPreparePipeline {
    func snapshots(for seed: String) -> [LoadingProgress] {
        [
            LoadingProgress(seed: seed, phase: "Seed", progress: 0.15),
            LoadingProgress(seed: seed, phase: "World DNA", progress: 0.35),
            LoadingProgress(seed: seed, phase: "Terrain bootstrap", progress: 0.60),
            LoadingProgress(seed: seed, phase: "Render payloads", progress: 0.82),
            LoadingProgress(seed: seed, phase: "Ready", progress: 1.0),
        ]
    }

    func makeWorldSession(seed: String) -> WorldSession {
        WorldSession(seed: seed)
    }
}
