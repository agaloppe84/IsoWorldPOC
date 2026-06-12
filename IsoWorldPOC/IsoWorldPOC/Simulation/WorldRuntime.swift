//
//  WorldRuntime.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Foundation
import simd

@MainActor
final class WorldRuntime {
    private let inputManager = InputManager()
    private var playerController: PlayerController
    private let playerGrounding = PlayerGrounding()
    private let cameraController = OrbitCameraController()
    private let chunkStreamer: ChunkDataStreamer
    private let snapshotBuilder = RenderSnapshotBuilder()
    private let fxRecipe = FXRecipe()
    private let fxBudget = FXBudget.v1Realtime
    private let audioRecipeResolver = AudioRecipeResolver()
    private let audioEngine = IsoAudioEngine()
    private let biomeSampler: BiomeSampler
    private let uiWorldDNA: UIWorldDNA
    private let lightingState = LightingState.defaultDay
    private let seedText: String
    private let worldSeed: WorldSeed
    private let worldDNA: WorldDNA
    private let saveRootURL: URL?
    private var frameIndex: UInt64 = 0
    private var simulationTime: Float = 0
    private var fxFrameState = FXFrameState()
    private var latestFXSnapshot = FXFrameSnapshot.empty
    private var latestAudioSnapshot = AudioRuntimeSnapshot.empty
    private var latestUIFrameSnapshot = UIFrameSnapshot.empty
    private var lastSimulationUpdateMs: Float = 0
    private var lastSnapshotBuildMs: Float = 0
    private var lastSnapshotBuildTiming = RenderSnapshotBuildTiming.empty
    private var lastGrounding = PlayerGroundingResult(
        position: .zero,
        groundSample: nil,
        playerGrounded: false,
        movementBlockedBySlope: false
    )

    private(set) var snapshot: RenderWorldSnapshot
    private(set) var frameSnapshot: EngineFrameSnapshot

    var playerPosition: SIMD3<Float> {
        playerController.position
    }

    var playerCharacterDNA: CharacterDNA {
        playerController.characterDNA
    }

    var playerAnimationSample: AnimationSample {
        playerController.animationSample
    }

    var playerFootIKResults: [AnimationFootSide: FootIKResult] {
        playerController.footIKResults
    }

    var playerRecentFootstepEvents: [FootstepEvent] {
        playerController.recentFootstepEvents
    }

    var fxSnapshot: FXFrameSnapshot {
        latestFXSnapshot
    }

    var audioSnapshot: AudioRuntimeSnapshot {
        latestAudioSnapshot
    }

    var uiFrameSnapshot: UIFrameSnapshot {
        latestUIFrameSnapshot
    }

    var currentSaveRootURL: URL? {
        saveRootURL
    }

    init(
        worldSession: WorldSession? = nil,
        debugOptions: RenderSnapshotDebugOptions = .defaults
    ) {
        let restoredPlayer = worldSession?.saveManifest?.player
        let resolvedWorldSeed = worldSession?.saveManifest?.world.worldSeed ??
            worldSession?.worldSeed ??
            ProceduralChunkDataFactory.activeSeed
        let resolvedSeedText = worldSession?.saveManifest?.world.seedText ??
            worldSession?.seed ??
            "seed-\(resolvedWorldSeed.value)"
        let resolvedWorldDNA = worldSession?.saveManifest?.world.worldDNA ??
            worldSession?.dna ??
            WorldDNA.make(worldSeed: resolvedWorldSeed)
        let spawnPosition = restoredPlayer?.position ?? worldSession?.spawnPosition
        let characterDNA = CharacterDNA.makePlayer(worldSeed: resolvedWorldSeed)
        self.seedText = resolvedSeedText
        self.worldSeed = resolvedWorldSeed
        self.worldDNA = resolvedWorldDNA
        self.saveRootURL = worldSession?.saveRootURL
        self.playerController = PlayerController(position: SIMD3<Float>(
            spawnPosition?.x ?? 0,
            spawnPosition?.y ?? 0,
            spawnPosition?.z ?? 0
        ), characterDNA: characterDNA)
        self.biomeSampler = BiomeSampler(seed: resolvedWorldSeed)
        self.uiWorldDNA = UIWorldDNA.make(worldSeed: resolvedWorldSeed)
        self.chunkStreamer = ChunkDataStreamer(
            worldSeed: resolvedWorldSeed,
            initialChunks: worldSession?.initialChunks ?? []
        )

        let emptySnapshot = Self.makeEmptySnapshot()
        self.snapshot = emptySnapshot
        self.frameSnapshot = EngineFrameSnapshot(
            frameIndex: 0,
            worldSeed: resolvedWorldSeed,
            simulationTime: 0,
            deltaTime: 0,
            render: emptySnapshot,
            debug: DebugSnapshot(frameIndex: 0)
        )

        if let restoredPlayer {
            cameraController.cameraYaw = restoredPlayer.cameraYaw
            cameraController.cameraPitch = restoredPlayer.cameraPitch
        }

        chunkStreamer.update(
            around: playerController.position,
            forcedLODLevel: debugOptions.forcedLODLevel
        )
        latestUIFrameSnapshot = makeUIFrameSnapshot()
        lastSimulationUpdateMs = 0
        let snapshotStart = currentTimeMilliseconds()
        let snapshotResult = makeSnapshot(debugOptions: debugOptions)
        snapshot = snapshotResult.snapshot
        lastSnapshotBuildTiming = snapshotResult.timing
        lastSnapshotBuildMs = Float(currentTimeMilliseconds() - snapshotStart)
        frameSnapshot = makeFrameSnapshot(deltaTime: 0)
    }

    func handleKeyDown(keyCode: UInt16) {
        inputManager.keyDown(keyCode: keyCode)
    }

    func handleKeyUp(keyCode: UInt16) {
        inputManager.keyUp(keyCode: keyCode)
    }

    func resetKeyboard() {
        inputManager.resetKeyboard()
    }

    func update(
        deltaTime: Float,
        debugOptions: RenderSnapshotDebugOptions
    ) -> RenderWorldSnapshot {
        let simulationStart = currentTimeMilliseconds()
        updateSimulation(deltaTime: deltaTime, debugOptions: debugOptions)
        lastSimulationUpdateMs = Float(currentTimeMilliseconds() - simulationStart)
        frameIndex += 1
        if !debugOptions.freezeSimulation {
            simulationTime += deltaTime
        }
        updateFX(deltaTime: deltaTime, debugOptions: debugOptions)
        updateAudio(debugOptions: debugOptions)
        updateUI()

        let snapshotStart = currentTimeMilliseconds()
        let snapshotResult = makeSnapshot(debugOptions: debugOptions)
        snapshot = snapshotResult.snapshot
        lastSnapshotBuildTiming = snapshotResult.timing
        lastSnapshotBuildMs = Float(currentTimeMilliseconds() - snapshotStart)
        frameSnapshot = makeFrameSnapshot(deltaTime: deltaTime)

        return snapshot
    }

    func applyDebugMetrics(to debugMetrics: DebugMetrics) {
        let camera = snapshot.camera

        debugMetrics.inputState = inputManager.state
        debugMetrics.controllerName = inputManager.controllerName
        debugMetrics.playerPosition = playerController.position
        debugMetrics.terrainHeightUnderPlayer = lastGrounding.terrainHeight
        debugMetrics.slopeUnderPlayer = lastGrounding.slopeUnderPlayer
        debugMetrics.playerGrounded = lastGrounding.playerGrounded
        debugMetrics.maxWalkableSlope = playerGrounding.maxWalkableSlope
        debugMetrics.currentGroundChunk = lastGrounding.currentGroundChunk
        debugMetrics.currentChunk = chunkStreamer.currentChunk
        debugMetrics.activeChunkCount = chunkStreamer.activeChunkCount
        debugMetrics.visibleChunkCount = chunkStreamer.visibleChunkCount
        debugMetrics.lodCandidateChunkCount = frameSnapshot.debug.lodStats.candidateChunkCount
        debugMetrics.lodCulledChunkCount = frameSnapshot.debug.lodStats.culledChunkCount
        debugMetrics.lod0ChunkCount = frameSnapshot.debug.lodStats.lod0ChunkCount
        debugMetrics.lod1ChunkCount = frameSnapshot.debug.lodStats.lod1ChunkCount
        debugMetrics.lod2ChunkCount = frameSnapshot.debug.lodStats.lod2ChunkCount
        debugMetrics.lod3ChunkCount = frameSnapshot.debug.lodStats.lod3ChunkCount
        debugMetrics.generatedChunkCount = chunkStreamer.generatedChunkCount
        debugMetrics.cachedChunkCount = chunkStreamer.cachedChunkCount
        debugMetrics.approximateTriangleCount = chunkStreamer.approximateTriangleCount
        debugMetrics.approximatePropCount = chunkStreamer.approximatePropCount
        debugMetrics.averageChunkDataGenerationMs = chunkStreamer.averageChunkDataGenerationMs
        debugMetrics.estimatedChunkCPUBytes = chunkStreamer.estimatedChunkCPUBytes
        debugMetrics.chunkJobsQueued = chunkStreamer.chunkJobsQueued
        debugMetrics.chunkJobsGenerating = frameSnapshot.debug.jobs.activeJobCount
        debugMetrics.chunksReadyForUpload = frameSnapshot.debug.chunksReadyForUpload
        debugMetrics.chunkUploadsThisFrame = frameSnapshot.debug.chunkUploadsThisFrame
        debugMetrics.cameraYaw = camera.yaw
        debugMetrics.cameraPitch = camera.pitch
        debugMetrics.cameraDistance = camera.distance
        debugMetrics.movementMode = "cameraRelative"
        debugMetrics.sunDirection = SIMD3<Float>(
            snapshot.lighting.sunDirection.x,
            snapshot.lighting.sunDirection.y,
            snapshot.lighting.sunDirection.z
        )
        debugMetrics.sunIntensity = snapshot.lighting.sunIntensity
        debugMetrics.ambientIntensity = snapshot.lighting.ambientIntensity
        debugMetrics.shadowsEnabled = snapshot.lighting.shadowsEnabled
        debugMetrics.applySnapshotTiming(lastSnapshotBuildTiming)
    }

    var simulationUpdateMs: Float {
        lastSimulationUpdateMs
    }

    var snapshotBuildMs: Float {
        lastSnapshotBuildMs
    }

    var snapshotBuildTiming: RenderSnapshotBuildTiming {
        lastSnapshotBuildTiming
    }

    func makePersistenceCapture() -> WorldRuntimePersistenceCapture {
        let playerWorldPosition = WorldPosition(
            x: playerController.position.x,
            y: playerController.position.y,
            z: playerController.position.z
        )
        let playerChunk = chunkStreamer.currentChunk
        let playerRegion = RegionCoordinate.containing(playerChunk, regionSizeInChunks: 8)
        let playerState = SavePlayerState(
            profile: PlayerProfile()
                .recordingRecentSeed(seedText),
            position: playerWorldPosition,
            region: playerRegion,
            cameraYaw: cameraController.cameraYaw,
            cameraPitch: cameraController.cameraPitch
        )
        let playerEntityID = StableID.entity(
            worldSeed: worldSeed,
            localIndex: 0
        )
        let runtimeState = playerController.characterRuntimeState
        let playerEntity = EntityPersistenceState(
            id: playerEntityID,
            kind: .player,
            displayName: "Player",
            worldPosition: playerWorldPosition,
            chunk: playerChunk,
            region: playerRegion,
            lastModifiedTick: frameIndex,
            tags: ["entity.player"],
            components: [
                EntityComponentState(
                    componentID: "character.runtime",
                    payloadHash: StableHash.make { builder in
                        builder.combine("character.runtime")
                        builder.combine(runtimeState.health)
                        builder.combine(runtimeState.stamina)
                        builder.combine(runtimeState.fatigue)
                        builder.combine(runtimeState.wetness)
                        builder.combine(runtimeState.dirtiness)
                        builder.combine(runtimeState.movementStance.rawValue)
                    },
                    scalarValues: [
                        "health": Double(runtimeState.health),
                        "stamina": Double(runtimeState.stamina),
                        "fatigue": Double(runtimeState.fatigue),
                        "wetness": Double(runtimeState.wetness),
                        "dirtiness": Double(runtimeState.dirtiness),
                    ],
                    stringValues: [
                        "movementStance": runtimeState.movementStance.rawValue,
                    ]
                ),
            ]
        )
        let entityStore = EntityStateStore().upserting(playerEntity)
        let chunkDelta = entityStore.chunkDelta(for: playerChunk, tick: frameIndex)
        let regionDeltaStore = RegionDeltaStore(worldSeed: worldSeed)
            .adding(chunkDelta)
        let dirtyTracker = DirtyTracker()
            .markingDirty(
                coordinate: playerChunk,
                tick: frameIndex,
                systemID: "runtime.player",
                reason: .entityState
            )

        return WorldRuntimePersistenceCapture(
            seedText: seedText,
            worldSeed: worldSeed,
            worldDNA: worldDNA,
            playerState: playerState,
            playerEntityID: playerEntityID,
            currentChunk: playerChunk,
            activeChunkCoordinates: chunkStreamer.activeCoordinatesForPersistence,
            visibleChunkCoordinates: snapshot.chunks.map(\.coordinate),
            frameIndex: frameIndex,
            simulationTime: simulationTime,
            dirtyTracker: dirtyTracker,
            regionDeltaStore: regionDeltaStore,
            entityStore: entityStore
        )
    }

    private func updateSimulation(
        deltaTime: Float,
        debugOptions: RenderSnapshotDebugOptions
    ) {
        guard !debugOptions.freezeSimulation else {
            updateChunkVisibilityWhenStreamingIsFrozen(debugOptions: debugOptions)
            return
        }

        cameraController.updateOrbit(deltaTime: deltaTime, input: inputManager.state)
        var cameraFieldOfView = cameraController
            .renderState(following: playerController.position)
            .fieldOfViewDegrees

        updateChunks(
            around: playerController.position,
            fieldOfViewDegrees: cameraFieldOfView,
            debugOptions: debugOptions
        )

        let previousPosition = playerController.position
        let proposedPosition = playerController.proposedHorizontalPosition(
            deltaTime: deltaTime,
            input: inputManager.state,
            movementRight: cameraController.movementRight,
            movementForward: cameraController.movementForward
        )
        let previousGround = chunkStreamer.terrainGroundSample(at: previousPosition)
        let proposedGround = chunkStreamer.terrainGroundSample(at: proposedPosition)
        let grounding = playerGrounding.resolve(
            previousPosition: previousPosition,
            proposedPosition: proposedPosition,
            proposedGround: proposedGround,
            previousGround: previousGround
        )

        _ = playerController.applyGroundedPosition(grounding.position)
        playerController.updateMotion(
            deltaTime: deltaTime,
            previousPosition: previousPosition,
            input: inputManager.state,
            grounding: grounding
        )
        cameraFieldOfView = cameraController
            .renderState(following: playerController.position)
            .fieldOfViewDegrees
        updateChunks(
            around: playerController.position,
            fieldOfViewDegrees: cameraFieldOfView,
            debugOptions: debugOptions
        )
        lastGrounding = grounding
    }

    private func updateChunks(
        around playerPosition: SIMD3<Float>,
        fieldOfViewDegrees: Float,
        debugOptions: RenderSnapshotDebugOptions
    ) {
        if debugOptions.freezeChunkStreaming {
            chunkStreamer.updateActiveVisibility(
                around: playerPosition,
                fieldOfViewDegrees: fieldOfViewDegrees,
                forcedLODLevel: debugOptions.forcedLODLevel
            )
        } else {
            chunkStreamer.update(
                around: playerPosition,
                fieldOfViewDegrees: fieldOfViewDegrees,
                forcedLODLevel: debugOptions.forcedLODLevel
            )
        }
    }

    private func updateChunkVisibilityWhenStreamingIsFrozen(debugOptions: RenderSnapshotDebugOptions) {
        let cameraFieldOfView = cameraController
            .renderState(following: playerController.position)
            .fieldOfViewDegrees
        chunkStreamer.updateActiveVisibility(
            around: playerController.position,
            fieldOfViewDegrees: cameraFieldOfView,
            forcedLODLevel: debugOptions.forcedLODLevel
        )
    }

    private func makeSnapshot(debugOptions: RenderSnapshotDebugOptions) -> RenderSnapshotBuildResult {
        snapshotBuilder.makeInstrumentedSnapshot(
            chunkStreamer: chunkStreamer,
            camera: cameraController.renderState(following: playerController.position),
            lighting: lightingState,
            debugOptions: debugOptions,
            fx: latestFXSnapshot,
            ui: latestUIFrameSnapshot
        )
    }

    private func updateFX(
        deltaTime: Float,
        debugOptions: RenderSnapshotDebugOptions
    ) {
        guard !debugOptions.freezeSimulation else {
            latestFXSnapshot = fxFrameState.snapshot(budget: fxBudget)
            return
        }

        fxFrameState.advance(deltaTime: deltaTime)

        let camera = cameraController.renderState(following: playerController.position)
        let emittedFX = fxRecipe.makeFootstepFX(
            from: playerController.recentFootstepEvents,
            context: FXContext(
                worldSeed: worldSeed,
                simulationTime: simulationTime,
                cameraPosition: camera.position
            ),
            budget: fxBudget
        )
        latestFXSnapshot = fxFrameState.merge(emittedFX, budget: fxBudget)
    }

    private func updateAudio(debugOptions: RenderSnapshotDebugOptions) {
        guard !debugOptions.freezeSimulation else {
            latestAudioSnapshot = audioEngine.update(maxEventsPerFrame: 0)
            return
        }

        let camera = cameraController.renderState(following: playerController.position)
        let events = audioRecipeResolver.makeFootstepEvents(
            from: playerController.recentFootstepEvents,
            context: AudioContext(
                worldSeed: worldSeed,
                simulationTime: simulationTime,
                listenerPosition: camera.position
            )
        )

        audioEngine.post(contentsOf: events)
        latestAudioSnapshot = audioEngine.update()
    }

    private func updateUI() {
        latestUIFrameSnapshot = makeUIFrameSnapshot()
    }

    private func makeUIFrameSnapshot() -> UIFrameSnapshot {
        let terrainSample = lastGrounding.groundSample?.terrainSample
        let biome = terrainSample?.materialWeights.primaryBiome ??
            biomeSampler.biome(at: WorldPosition(
                x: playerController.position.x,
                y: playerController.position.y,
                z: playerController.position.z
            ))

        return UIFrameSnapshot.make(
            worldSeed: worldSeed,
            simulationTime: simulationTime,
            dna: uiWorldDNA,
            player: PlayerHUDState(runtimeState: playerController.characterRuntimeState),
            biome: biome,
            weather: makeWeatherHUDState(from: terrainSample),
            terrainPrompt: makeTerrainPrompt(),
            isVisible: true
        )
    }

    private func makeWeatherHUDState(from sample: TerrainSample?) -> WeatherHUDState {
        guard let sample else {
            return WeatherHUDState(kind: .clear, severity: 0, label: "Clear")
        }

        if sample.waterDepth > 0.12 || sample.moisture > 0.72 {
            return WeatherHUDState(
                kind: .wet,
                severity: min(max(sample.waterDepth + sample.moisture * 0.55, 0), 1),
                label: "Wet"
            )
        }

        if sample.temperature < 0.18 {
            return WeatherHUDState(
                kind: .cold,
                severity: min(max(0.18 - sample.temperature, 0), 1),
                label: "Cold"
            )
        }

        if sample.temperature > 0.78 && sample.moisture < 0.28 {
            return WeatherHUDState(
                kind: .dry,
                severity: min(max(sample.temperature - sample.moisture, 0), 1),
                label: "Dry"
            )
        }

        return WeatherHUDState(kind: .clear, severity: 0, label: "Clear")
    }

    private func makeTerrainPrompt() -> String? {
        if lastGrounding.movementBlockedBySlope {
            return "STEEP"
        }

        guard let surfaceClass = lastGrounding.groundSample?.surfaceClass else {
            return nil
        }

        switch surfaceClass {
        case .climbable:
            return "CLIMB"
        case .steep:
            return "SLOPE"
        case .dangerous:
            return "DANGER"
        case .blocked:
            return "BLOCKED"
        case .walkable:
            return nil
        }
    }

    private func makeFrameSnapshot(deltaTime: Float) -> EngineFrameSnapshot {
        EngineFrameSnapshot(
            frameIndex: frameIndex,
            worldSeed: worldSeed,
            simulationTime: simulationTime,
            deltaTime: deltaTime,
            render: snapshot,
            debug: chunkStreamer.debugSnapshot(
                frameIndex: frameIndex,
                currentGroundChunk: lastGrounding.currentGroundChunk
            )
        )
    }

    private static func makeEmptySnapshot() -> RenderWorldSnapshot {
        RenderWorldSnapshot(
            camera: CameraRenderState(
                position: WorldPosition(x: 0, y: 0, z: 1),
                target: WorldPosition(x: 0, y: 0, z: 0),
                fieldOfViewDegrees: 35,
                yaw: 0,
                pitch: 0,
                distance: 1
            ),
            chunks: []
        )
    }

    private func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
