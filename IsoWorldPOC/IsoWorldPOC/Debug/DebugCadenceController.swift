import Foundation
import MetalKit

@MainActor
final class DebugCadenceController {
    private weak var view: MTKView?
    private var timer: Timer?
    private var policy: RenderCadencePolicy?
    private var drawScheduled = false

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
        startContinuousDriverIfNeeded(for: policy)
        requestDraw()
    }

    func requestDraw() {
        guard let view else {
            return
        }

        guard view.window != nil else {
            view.setNeedsDisplay(view.bounds)
            return
        }

        guard !drawScheduled else {
            return
        }

        drawScheduled = true
        Task { @MainActor [weak self] in
            self?.drawScheduledFrame()
        }
    }

    private func configureView(for policy: RenderCadencePolicy) {
        guard let view else {
            return
        }

        view.preferredFramesPerSecond = policy.maxFPS
        view.enableSetNeedsDisplay = false
        view.isPaused = true
    }

    private func startContinuousDriverIfNeeded(for policy: RenderCadencePolicy) {
        guard let fps = driverFPS(for: policy) else {
            return
        }

        let interval = 1.0 / Double(max(fps, 1))
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.requestDraw()
            }
        }

        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func driverFPS(for policy: RenderCadencePolicy) -> Int? {
        switch policy.mode {
        case .onDemand:
            nil
        case let .throttled(fps):
            fps
        case .displayLinked, .benchmarkFixedStep:
            policy.maxFPS
        }
    }

    private func drawScheduledFrame() {
        drawScheduled = false

        guard let view else {
            return
        }

        guard view.window != nil else {
            view.setNeedsDisplay(view.bounds)
            return
        }

        view.draw()
    }
}
