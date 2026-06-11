enum DebugWorldRunMode: String, CaseIterable, Identifiable {
    case pausedInspection
    case slowInspection
    case liveGameplay
    case benchmark

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .pausedInspection:
            "Paused"
        case .slowInspection:
            "Slow"
        case .liveGameplay:
            "Live"
        case .benchmark:
            "Benchmark"
        }
    }

    var cadencePolicy: RenderCadencePolicy {
        switch self {
        case .pausedInspection:
            RenderCadencePolicy(
                mode: .onDemand,
                maxFPS: 1,
                renderOnlyWhenDirty: true,
                allowContinuousAnimation: false
            )
        case .slowInspection:
            RenderCadencePolicy(
                mode: .throttled(fps: 15),
                maxFPS: 15,
                renderOnlyWhenDirty: false,
                allowContinuousAnimation: true
            )
        case .liveGameplay:
            RenderCadencePolicy(
                mode: .displayLinked,
                maxFPS: 60,
                renderOnlyWhenDirty: false,
                allowContinuousAnimation: true
            )
        case .benchmark:
            RenderCadencePolicy(
                mode: .benchmarkFixedStep,
                maxFPS: 60,
                renderOnlyWhenDirty: false,
                allowContinuousAnimation: true
            )
        }
    }

    var metricsRefreshInterval: Double {
        switch self {
        case .pausedInspection:
            0.50
        case .slowInspection:
            0.50
        case .liveGameplay:
            0.50
        case .benchmark:
            1.00
        }
    }
}
