//
//  RealityKitGameView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import Combine
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
        private var updateSubscription: (any Cancellable)?

        init(debugMetrics: DebugMetrics) {
            self.debugMetrics = debugMetrics
        }

        func configureScene(in arView: ARView) {
            arView.scene.anchors.removeAll()

            let worldAnchor = AnchorEntity(world: .zero)
            let playerEntity = DebugSceneFactory.makePlayerEntity()
            self.playerEntity = playerEntity

            worldAnchor.addChild(DebugSceneFactory.makeReferenceFloor())
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
            let position = playerController.update(deltaTime: deltaTime, input: inputManager.state)
            playerEntity?.position = position
            cameraController.update(following: position)
            debugMetrics.inputState = inputManager.state
            debugMetrics.controllerName = inputManager.controllerName
            debugMetrics.playerPosition = position
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
