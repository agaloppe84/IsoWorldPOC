//
//  WorldRuntime.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import simd

@MainActor
final class WorldRuntime {
    private let inputManager = InputManager()
    private var playerController = PlayerController()
    private let playerGrounding = PlayerGrounding()
    private let cameraController = OrbitCameraController()
    private let chunkStreamer = ChunkDataStreamer()
    private let snapshotBuilder = RenderSnapshotBuilder()
    private let lightingState = LightingState.defaultDay
    private var frameIndex: UInt64 = 0
    private var simulationTime: Float = 0
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

    init(debugOptions: RenderSnapshotDebugOptions = .defaults) {
        let emptySnapshot = Self.makeEmptySnapshot()
        self.snapshot = emptySnapshot
        self.frameSnapshot = EngineFrameSnapshot(
            frameIndex: 0,
            worldSeed: ProceduralChunkDataFactory.activeSeed,
            simulationTime: 0,
            deltaTime: 0,
            render: emptySnapshot,
            debug: DebugSnapshot(frameIndex: 0)
        )

        chunkStreamer.update(around: .zero)
        snapshot = makeSnapshot(debugOptions: debugOptions)
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
        updateSimulation(deltaTime: deltaTime)
        frameIndex += 1
        simulationTime += deltaTime
        snapshot = makeSnapshot(debugOptions: debugOptions)
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
    }

    private func updateSimulation(deltaTime: Float) {
        cameraController.updateOrbit(deltaTime: deltaTime, input: inputManager.state)
        var cameraFieldOfView = cameraController
            .renderState(following: playerController.position)
            .fieldOfViewDegrees
        chunkStreamer.update(
            around: playerController.position,
            fieldOfViewDegrees: cameraFieldOfView
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
        chunkStreamer.updateActiveVisibility(
            around: playerController.position,
            fieldOfViewDegrees: cameraFieldOfView
        )
        lastGrounding = grounding
    }

    private func makeSnapshot(debugOptions: RenderSnapshotDebugOptions) -> RenderWorldSnapshot {
        snapshotBuilder.makeSnapshot(
            chunkStreamer: chunkStreamer,
            camera: cameraController.renderState(following: playerController.position),
            lighting: lightingState,
            debugOptions: debugOptions
        )
    }

    private func makeFrameSnapshot(deltaTime: Float) -> EngineFrameSnapshot {
        EngineFrameSnapshot(
            frameIndex: frameIndex,
            worldSeed: ProceduralChunkDataFactory.activeSeed,
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
}
