import Combine
import EngineCore
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var mode: AppMode
    @Published var seedInput: String
    @Published private(set) var loadingProgress: LoadingProgress?
    @Published private(set) var currentWorldSession: WorldSession?
    @Published private(set) var currentToolSession: ToolSession?
    @Published private(set) var runtimeSaveMessage: String?
    @Published private(set) var lastRuntimeSaveReport: SaveInspectionReport?

    private let engineCore: EngineCoreFacade
    private let worldPreparePipeline: WorldPreparePipeline
    private let worldRuntimeSaveService: WorldRuntimeSaveService
    private var loadingTask: Task<Void, Never>?

    init(
        mode: AppMode = .mainMenu,
        seedInput: String = "isoworld-seed-001",
        engineCore: EngineCoreFacade = EngineCoreFacade(),
        worldPreparePipeline: WorldPreparePipeline = WorldPreparePipeline(),
        worldRuntimeSaveService: WorldRuntimeSaveService = WorldRuntimeSaveService()
    ) {
        self.mode = mode
        self.seedInput = seedInput
        self.engineCore = engineCore
        self.worldPreparePipeline = worldPreparePipeline
        self.worldRuntimeSaveService = worldRuntimeSaveService
    }

    deinit {
        loadingTask?.cancel()
    }

    func showMainMenu() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingProgress = nil
        currentWorldSession = nil
        currentToolSession = nil
        runtimeSaveMessage = nil
        lastRuntimeSaveReport = nil
        mode = .mainMenu
    }

    func openDebugWorld() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingProgress = nil
        currentWorldSession = nil
        currentToolSession = nil
        runtimeSaveMessage = nil
        lastRuntimeSaveReport = nil

        let session = engineCore.makeDebugWorldSession()
        mode = .debugWorld(session.id)
    }

    func openToolsHub() {
        loadingTask?.cancel()
        loadingTask = nil
        loadingProgress = nil
        currentWorldSession = nil
        runtimeSaveMessage = nil

        let session = engineCore.makeToolSession(seedText: normalizedSeed())
        currentToolSession = session
        mode = .toolsHub(session.id)
    }

    func prepareWorldFromSeed() {
        let seed = normalizedSeed()
        let loadingSessionID = LoadingSessionID()

        loadingTask?.cancel()
        currentWorldSession = nil
        currentToolSession = nil
        runtimeSaveMessage = nil
        loadingProgress = .initial(seed: seed)
        mode = .preparingWorld(loadingSessionID)

        loadingTask = Task { [weak self] in
            await self?.runWorldPreparation(seed: seed)
        }
    }

    func saveCurrentWorld(runtime: WorldRuntime?) {
        guard let runtime else {
            runtimeSaveMessage = "World runtime unavailable"
            return
        }

        let slotID = saveSlotID(for: currentWorldSession)
        let rootURL = currentWorldSession?.saveRootURL ?? defaultSaveRootURL(for: slotID)
        let displayName = currentWorldSession?.saveManifest?.displayName ?? "Runtime Save"
        let worldName = currentWorldSession?.saveManifest?.worldName ?? "IsoWorld Runtime"

        runtimeSaveMessage = "Saving"
        Task { @MainActor [weak self, runtime] in
            await self?.runRuntimeSave(
                runtime: runtime,
                rootURL: rootURL,
                slotID: slotID,
                displayName: displayName,
                worldName: worldName
            )
        }
    }

    func openSavedWorld(from saveRootURL: URL) {
        loadingTask?.cancel()
        loadingTask = nil
        currentWorldSession = nil
        currentToolSession = nil
        runtimeSaveMessage = "Loading"
        mode = .preparingWorld(LoadingSessionID())

        Task { @MainActor [weak self] in
            await self?.runRuntimeLoad(from: saveRootURL)
        }
    }

    private func runWorldPreparation(seed: String) async {
        do {
            let request = WorldPrepareRequest(seedText: seed)
            let session = try await worldPreparePipeline.prepareWorld(request: request) { [weak self] progress in
                self?.loadingProgress = progress
            }

            guard !Task.isCancelled else {
                return
            }

            currentWorldSession = session
            currentToolSession = nil
            runtimeSaveMessage = nil
            mode = .realWorld(session.id)
            loadingTask = nil
        } catch is CancellationError {
            guard !Task.isCancelled else {
                return
            }

            loadingProgress = LoadingProgress(seed: seed, phase: "Cancelled", progress: 0)
            loadingTask = nil
        } catch {
            guard !Task.isCancelled else {
                return
            }

            mode = .error(AppErrorState(
                title: "World preparation failed",
                message: error.localizedDescription
            ))
            loadingProgress = nil
            loadingTask = nil
        }
    }

    private func runRuntimeSave(
        runtime: WorldRuntime,
        rootURL: URL,
        slotID: SaveSlotID,
        displayName: String,
        worldName: String
    ) async {
        do {
            let result = try await worldRuntimeSaveService.save(
                runtime: runtime,
                to: rootURL,
                slotID: slotID,
                displayName: displayName,
                worldName: worldName
            )
            lastRuntimeSaveReport = result.inspection
            runtimeSaveMessage = "Saved g\(result.manifest.integrity.generation)"
        } catch {
            runtimeSaveMessage = "Save failed"
        }
    }

    private func runRuntimeLoad(from saveRootURL: URL) async {
        do {
            let result = try await worldRuntimeSaveService.load(from: saveRootURL)

            currentWorldSession = result.session
            currentToolSession = nil
            loadingProgress = nil
            lastRuntimeSaveReport = result.inspection
            runtimeSaveMessage = "Loaded g\(result.manifest.integrity.generation)"
            mode = .realWorld(result.session.id)
        } catch {
            mode = .error(AppErrorState(
                title: "World load failed",
                message: error.localizedDescription
            ))
            loadingProgress = nil
            runtimeSaveMessage = nil
        }
    }

    private func normalizedSeed() -> String {
        let trimmedSeed = seedInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSeed.isEmpty ? "isoworld-seed-001" : trimmedSeed
    }

    private func saveSlotID(for session: WorldSession?) -> SaveSlotID {
        if let slotID = session?.saveManifest?.slotID {
            return slotID
        }

        let seedValue = session?.worldSeed.value ?? WorldSeed(StableHash.make { builder in
            builder.combine(normalizedSeed())
        }.value).value
        return SaveSlotID("runtime-\(seedValue)")
    }

    private func defaultSaveRootURL(for slotID: SaveSlotID) -> URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return root
            .appendingPathComponent("IsoWorldPOC", isDirectory: true)
            .appendingPathComponent("Saves", isDirectory: true)
            .appendingPathComponent(slotID.rawValue, isDirectory: true)
    }
}
