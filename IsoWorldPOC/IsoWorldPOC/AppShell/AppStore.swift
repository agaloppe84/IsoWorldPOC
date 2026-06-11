import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var mode: AppMode
    @Published var seedInput: String
    @Published private(set) var loadingProgress: LoadingProgress?
    @Published private(set) var currentWorldSession: WorldSession?

    private let engineCore: EngineCoreFacade
    private let worldPreparePipeline: WorldPreparePipeline
    private var loadingTask: Task<Void, Never>?

    init(
        mode: AppMode = .mainMenu,
        seedInput: String = "isoworld-seed-001",
        engineCore: EngineCoreFacade = EngineCoreFacade(),
        worldPreparePipeline: WorldPreparePipeline = WorldPreparePipeline()
    ) {
        self.mode = mode
        self.seedInput = seedInput
        self.engineCore = engineCore
        self.worldPreparePipeline = worldPreparePipeline
    }

    deinit {
        loadingTask?.cancel()
    }

    func showMainMenu() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingProgress = nil
        currentWorldSession = nil
        mode = .mainMenu
    }

    func openDebugWorld() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingProgress = nil
        currentWorldSession = nil

        let session = engineCore.makeDebugWorldSession()
        mode = .debugWorld(session.id)
    }

    func openToolsHub() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingProgress = nil

        let session = engineCore.makeToolSession()
        mode = .toolsHub(session.id)
    }

    func prepareWorldFromSeed() {
        let seed = normalizedSeed()
        let loadingSessionID = LoadingSessionID()

        loadingTask?.cancel()
        currentWorldSession = nil
        loadingProgress = .initial(seed: seed)
        mode = .preparingWorld(loadingSessionID)

        loadingTask = Task { [weak self] in
            await self?.runWorldPreparation(seed: seed)
        }
    }

    private func runWorldPreparation(seed: String) async {
        do {
            let session = try await worldPreparePipeline.prepareWorld(seed: seed) { [weak self] progress in
                self?.loadingProgress = progress
            }

            guard !Task.isCancelled else {
                return
            }

            currentWorldSession = session
            mode = .realWorld(session.id)
            loadingTask = nil
        } catch {
            guard !Task.isCancelled else {
                return
            }

            loadingProgress = LoadingProgress(seed: seed, phase: "Cancelled", progress: 0)
            loadingTask = nil
        }
    }

    private func normalizedSeed() -> String {
        let trimmedSeed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSeed.isEmpty ? "isoworld-seed-001" : trimmedSeed
    }
}
