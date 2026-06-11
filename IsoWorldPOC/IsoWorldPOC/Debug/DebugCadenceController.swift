import Foundation
import MetalKit

@MainActor
final class DebugCadenceController {
    private weak var view: MTKView?
    private var timer: Timer?
    private var policy: RenderCadencePolicy?

    deinit {
        timer?.invalidate()
    }

    func attach(view: MTKView) {
        self.view = view
    }

    func apply(policy: RenderCadencePolicy) {
        guard policy != self.policy else {
            return
        }

        self.policy = policy
        timer?.invalidate()
        timer = nil

        configureView(for: policy)
        startTimerIfNeeded(for: policy)
        requestDraw()
    }

    func requestDraw() {
        guard let view else {
            return
        }

        switch policy?.mode {
        case .displayLinked, .benchmarkFixedStep:
            return
        case .onDemand, .throttled, .none:
            view.setNeedsDisplay(view.bounds)
            view.draw()
        }
    }

    private func configureView(for policy: RenderCadencePolicy) {
        guard let view else {
            return
        }

        view.preferredFramesPerSecond = policy.maxFPS

        switch policy.mode {
        case .onDemand, .throttled:
            view.enableSetNeedsDisplay = true
            view.isPaused = true
        case .displayLinked, .benchmarkFixedStep:
            view.enableSetNeedsDisplay = false
            view.isPaused = false
        }
    }

    private func startTimerIfNeeded(for policy: RenderCadencePolicy) {
        guard case let .throttled(fps) = policy.mode else {
            return
        }

        let interval = 1.0 / Double(max(fps, 1))
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestDraw()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
