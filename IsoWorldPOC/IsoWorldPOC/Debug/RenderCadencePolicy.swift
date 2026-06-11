enum RenderCadenceMode: Equatable {
    case onDemand
    case throttled(fps: Int)
    case displayLinked
    case benchmarkFixedStep

    var displayName: String {
        switch self {
        case .onDemand:
            "on demand"
        case let .throttled(fps):
            "throttled \(fps) fps"
        case .displayLinked:
            "display linked"
        case .benchmarkFixedStep:
            "benchmark fixed"
        }
    }
}

struct RenderCadencePolicy: Equatable {
    let mode: RenderCadenceMode
    let maxFPS: Int
    let renderOnlyWhenDirty: Bool
    let allowContinuousAnimation: Bool

    var displayName: String {
        mode.displayName
    }
}
