//
//  RealityKitGameView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import Combine
import EngineCore
import RealityKit
import SwiftUI

struct RealityKitGameView: NSViewRepresentable {
    let debugMetrics: DebugMetrics

    func makeCoordinator() -> Coordinator {
        Coordinator(debugMetrics: debugMetrics)
    }

    func makeNSView(context: Context) -> ARView {
        let arView = KeyboardControllableARView(frame: .zero)
        arView.onKeyDown = { keyCode in
            context.coordinator.inputManager.keyDown(keyCode: keyCode)
        }
        arView.onKeyUp = { keyCode in
            context.coordinator.inputManager.keyUp(keyCode: keyCode)
        }
        arView.onKeyboardReset = {
            context.coordinator.inputManager.resetKeyboard()
        }

        context.coordinator.configureScene(in: arView)
        return arView
    }

    func updateNSView(_ nsView: ARView, context: Context) {}

    @MainActor
    final class Coordinator {
        let inputManager = InputManager()

        private let debugMetrics: DebugMetrics
        private var playerController = PlayerController()
        private let cameraController = CameraController()
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

            if terrainManager.activeChunkCount == 0 {
                worldAnchor.addChild(DebugSceneFactory.makeReferenceFloor())
            }

            worldAnchor.addChild(DebugSceneFactory.makeAxisMarkers())
            worldAnchor.addChild(playerEntity)
            worldAnchor.addChild(DebugSceneFactory.makeLight())
            worldAnchor.addChild(cameraController.camera)

            arView.scene.addAnchor(worldAnchor)

            updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.update(deltaTime: Float(event.deltaTime))
            }
        }

        private func update(deltaTime: Float) {
            updatePerformanceMetrics(deltaTime: deltaTime)

            let horizontalPosition = playerController.update(deltaTime: deltaTime, input: inputManager.state)
            terrainManager?.update(around: horizontalPosition)

            let terrainSample = terrainManager?.terrainSample(at: horizontalPosition)
            let position = playerController.followTerrain(height: terrainSample?.height)

            playerEntity?.position = position
            cameraController.update(following: position)
            debugMetrics.inputState = inputManager.state
            debugMetrics.controllerName = inputManager.controllerName
            debugMetrics.playerPosition = position
            debugMetrics.terrainHeightUnderPlayer = terrainSample?.height
            debugMetrics.terrainSlopeUnderPlayer = terrainSample?.slope
            debugMetrics.currentChunk = terrainManager?.currentChunk ?? .origin
            debugMetrics.activeChunkCount = terrainManager?.activeChunkCount ?? 0
            debugMetrics.visibleChunkCount = terrainManager?.visibleChunkCount ?? 0
            debugMetrics.generatedChunkCount = terrainManager?.generatedChunkCount ?? 0
            debugMetrics.cachedChunkCount = terrainManager?.cachedChunkCount ?? 0
            debugMetrics.approximateTriangleCount = terrainManager?.approximateTriangleCount ?? 0
            debugMetrics.approximatePropCount = terrainManager?.approximatePropCount ?? 0
            debugMetrics.averageChunkGenerationTimeMs = terrainManager?.averageChunkGenerationTimeMs
            debugMetrics.averageTerrainMeshBuildTimeMs = terrainManager?.averageTerrainMeshBuildTimeMs
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
}

private final class KeyboardControllableARView: ARView {
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    var onKeyboardReset: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event.keyCode)
    }

    override func flagsChanged(with event: NSEvent) {
        let isPressed = event.modifierFlags.contains(.shift)

        if isPressed {
            onKeyDown?(event.keyCode)
        } else {
            onKeyUp?(event.keyCode)
        }
    }

    override func resignFirstResponder() -> Bool {
        onKeyboardReset?()
        return super.resignFirstResponder()
    }
}
