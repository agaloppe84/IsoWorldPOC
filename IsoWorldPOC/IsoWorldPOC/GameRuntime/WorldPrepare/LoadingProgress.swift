import Foundation

struct LoadingWarning: Equatable, Sendable {
    let message: String
}

struct LoadingProgress: Equatable, Sendable {
    let seed: String
    let title: String
    let currentPhase: WorldPreparePhaseID
    let phaseName: String
    let phaseProgress: Double?
    let globalProgress: Double?
    let detail: String
    let warnings: [LoadingWarning]
    let canCancel: Bool

    var phase: String {
        phaseName
    }

    var progress: Double {
        globalProgress ?? 0
    }

    init(
        seed: String,
        title: String,
        currentPhase: WorldPreparePhaseID,
        phaseName: String,
        phaseProgress: Double?,
        globalProgress: Double?,
        detail: String,
        warnings: [LoadingWarning],
        canCancel: Bool
    ) {
        self.seed = seed
        self.title = title
        self.currentPhase = currentPhase
        self.phaseName = phaseName
        self.phaseProgress = phaseProgress
        self.globalProgress = globalProgress
        self.detail = detail
        self.warnings = warnings
        self.canCancel = canCancel
    }

    init(seed: String, phase: String, progress: Double) {
        self.seed = seed
        self.title = "Preparing World"
        self.currentPhase = .validateSeed
        self.phaseName = phase
        self.phaseProgress = progress
        self.globalProgress = progress
        self.detail = phase
        self.warnings = []
        self.canCancel = true
    }

    static func initial(seed: String) -> LoadingProgress {
        let phase = WorldPreparePhasePlan.v1.firstPhase

        return LoadingProgress(
            seed: seed,
            title: "Preparing World",
            currentPhase: phase.id,
            phaseName: phase.name,
            phaseProgress: 0,
            globalProgress: 0,
            detail: "Waiting for world preparation",
            warnings: [],
            canCancel: true
        )
    }
}
