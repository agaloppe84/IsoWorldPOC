//
//  RealityKitGameRenderer.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import Combine
import EngineCore
import RealityKit

@MainActor
final class RealityKitGameRenderer: GameRenderer {
    private let inputManager = InputManager()
    private let debugMetrics: DebugMetrics
    private var playerController = PlayerController()
    private let playerGrounding = PlayerGrounding()
    private let cameraController = CameraController()
    private let lightingSettings = SceneLightingSettings.standard
    private var playerEntity: Entity?
    private var terrainManager: ChunkTerrainManager?
    private var updateSubscription: (any Cancellable)?
    private var smoothedFrameTime: Float?

    init(debugMetrics: DebugMetrics) {
        self.debugMetrics = debugMetrics
    }

    func configureScene(in arView: ARView) {
        arView.scene.anchors.removeAll()

        let worldAnchor = AnchorEntity(world: .zero)
        let playerEntity = DebugSceneFactory.makePlayerEntity()
        let terrainManager = ChunkTerrainManager(anchor: worldAnchor)

        self.playerEntity = playerEntity
        self.terrainManager = terrainManager
        terrainManager.update(around: .zero)

        if terrainManager.activeChunkCount == 0 &&
            terrainManager.chunkJobsQueued == 0 &&
            terrainManager.chunkJobsGenerating == 0 {
            worldAnchor.addChild(DebugSceneFactory.makeReferenceFloor())
        }

        worldAnchor.addChild(DebugSceneFactory.makeAxisMarkers())
        worldAnchor.addChild(playerEntity)
        worldAnchor.addChild(DebugSceneFactory.makeLighting(settings: lightingSettings))
        worldAnchor.addChild(cameraController.camera)

        arView.scene.addAnchor(worldAnchor)

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.update(deltaTime: Float(event.deltaTime))
        }
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

    func update(deltaTime: Float) {
        updatePerformanceMetrics(deltaTime: deltaTime)

        cameraController.updateOrbit(deltaTime: deltaTime, input: inputManager.state)
        terrainManager?.setDebugOptions(
            showChunkBounds: debugMetrics.showChunkBounds,
            showChunkLabels: debugMetrics.showChunkLabels
        )
        terrainManager?.update(around: playerController.position)

        let previousPosition = playerController.position
        let proposedPosition = playerController.proposedHorizontalPosition(
            deltaTime: deltaTime,
            input: inputManager.state,
            movementRight: cameraController.movementRight,
            movementForward: cameraController.movementForward
        )
        let previousGround = terrainManager?.terrainGroundSample(at: previousPosition)
        let proposedGround = terrainManager?.terrainGroundSample(at: proposedPosition)
        let grounding = playerGrounding.resolve(
            previousPosition: previousPosition,
            proposedPosition: proposedPosition,
            proposedGround: proposedGround,
            previousGround: previousGround
        )
        let position = playerController.applyGroundedPosition(grounding.position)

        terrainManager?.updateActiveVisibility(around: position)

        playerEntity?.position = position
        cameraController.update(following: position)
        updateDebugMetrics(position: position, grounding: grounding)
    }

    private func updateDebugMetrics(
        position: SIMD3<Float>,
        grounding: PlayerGroundingResult
    ) {
        debugMetrics.inputState = inputManager.state
        debugMetrics.controllerName = inputManager.controllerName
        debugMetrics.playerPosition = position
        debugMetrics.terrainHeightUnderPlayer = grounding.terrainHeight
        debugMetrics.terrainSlopeUnderPlayer = grounding.slopeUnderPlayer
        debugMetrics.slopeUnderPlayer = grounding.slopeUnderPlayer
        debugMetrics.playerGrounded = grounding.playerGrounded
        debugMetrics.maxWalkableSlope = playerGrounding.maxWalkableSlope
        debugMetrics.currentGroundChunk = grounding.currentGroundChunk
        debugMetrics.currentChunk = terrainManager?.currentChunk ?? .origin
        debugMetrics.activeChunkCount = terrainManager?.activeChunkCount ?? 0
        debugMetrics.visibleChunkCount = terrainManager?.visibleChunkCount ?? 0
        debugMetrics.generatedChunkCount = terrainManager?.generatedChunkCount ?? 0
        debugMetrics.cachedChunkCount = terrainManager?.cachedChunkCount ?? 0
        debugMetrics.approximateTriangleCount = terrainManager?.approximateTriangleCount ?? 0
        debugMetrics.approximatePropCount = terrainManager?.approximatePropCount ?? 0
        debugMetrics.averageChunkGenerationTimeMs = terrainManager?.averageChunkGenerationTimeMs
        debugMetrics.averageTerrainMeshBuildTimeMs = terrainManager?.averageTerrainMeshBuildTimeMs
        debugMetrics.chunkJobsQueued = terrainManager?.chunkJobsQueued ?? 0
        debugMetrics.chunkJobsGenerating = terrainManager?.chunkJobsGenerating ?? 0
        debugMetrics.chunksReadyForUpload = terrainManager?.chunksReadyForUpload ?? 0
        debugMetrics.chunkUploadsThisFrame = terrainManager?.chunkUploadsThisFrame ?? 0
        debugMetrics.averageChunkDataGenerationMs = terrainManager?.averageChunkDataGenerationMs
        debugMetrics.averageChunkUploadMs = terrainManager?.averageChunkUploadMs
        debugMetrics.cameraYaw = cameraController.cameraYaw
        debugMetrics.cameraPitch = cameraController.cameraPitch
        debugMetrics.cameraDistance = cameraController.cameraDistance
        debugMetrics.movementMode = "cameraRelative"
        debugMetrics.sunDirection = lightingSettings.sunDirection
        debugMetrics.sunIntensity = lightingSettings.sunIntensity
        debugMetrics.ambientIntensity = lightingSettings.ambientIntensity
        debugMetrics.shadowsEnabled = lightingSettings.shadowsEnabled
    }

    private func updatePerformanceMetrics(deltaTime: Float) {
        guard deltaTime > 0 else {
            return
        }

        if let previous = smoothedFrameTime {
            smoothedFrameTime = previous * 0.9 + deltaTime * 0.1
        } else {
            smoothedFrameTime = deltaTime
        }

        guard let smoothedFrameTime else {
            return
        }

        debugMetrics.frameTimeMilliseconds = smoothedFrameTime * 1_000
        debugMetrics.framesPerSecond = 1 / smoothedFrameTime
    }
}
