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
    private let lightingState = LightingState.defaultDay
    private let worldSeed: WorldSeed
    private var frameIndex: UInt64 = 0
    private var simulationTime: Float = 0
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

    init(
        worldSession: WorldSession? = nil,
        debugOptions: RenderSnapshotDebugOptions = .defaults
    ) {
        let resolvedWorldSeed = worldSession?.worldSeed ?? ProceduralChunkDataFactory.activeSeed
        let spawnPosition = worldSession?.spawnPosition
        self.worldSeed = resolvedWorldSeed
        self.playerController = PlayerController(position: SIMD3<Float>(
            spawnPosition?.x ?? 0,
            spawnPosition?.y ?? 0,
            spawnPosition?.z ?? 0
        ))
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

        chunkStreamer.update(
            around: playerController.position,
            forcedLODLevel: debugOptions.forcedLODLevel
        )
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
        debugMetrics.terrainMaterialDebugMode = snapshot.debugOptions.terrainMaterialDebugMode
        debugMetrics.terrainSplatDebugLayerIndex = snapshot.debugOptions.terrainSplatDebugLayerIndex
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
            debugOptions: debugOptions
        )
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
