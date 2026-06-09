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
            let playerEntity = makePlayerEntity()
            self.playerEntity = playerEntity

            worldAnchor.addChild(makeReferenceFloor())
            worldAnchor.addChild(makeAxisMarkers())
            worldAnchor.addChild(playerEntity)
            worldAnchor.addChild(makeLight())
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

        private func makePlayerEntity() -> Entity {
            let player = Entity()
            player.name = "PlayerCapsule"

            let material = SimpleMaterial(
                color: .systemYellow,
                roughness: 0.35,
                isMetallic: false
            )

            let capsule = ModelEntity(
                mesh: .generateBox(size: [0.42, 0.95, 0.42], cornerRadius: 0.2),
                materials: [material]
            )
            capsule.position = [0, 0.48, 0]

            player.addChild(capsule)

            return player
        }

        private func makeReferenceFloor() -> Entity {
            let floor = Entity()
            floor.name = "DebugReferenceFloor"

            let floorMaterial = SimpleMaterial(
                color: .init(red: 0.12, green: 0.13, blue: 0.14, alpha: 1),
                roughness: 0.8,
                isMetallic: false
            )
            let floorEntity = ModelEntity(
                mesh: .generateBox(size: [14, 0.02, 14]),
                materials: [floorMaterial]
            )
            floorEntity.position = [0, -0.02, 0]
            floor.addChild(floorEntity)

            let minorLineMaterial = SimpleMaterial(
                color: .init(red: 0.32, green: 0.34, blue: 0.36, alpha: 1),
                roughness: 0.7,
                isMetallic: false
            )
            let majorLineMaterial = SimpleMaterial(
                color: .init(red: 0.50, green: 0.52, blue: 0.55, alpha: 1),
                roughness: 0.7,
                isMetallic: false
            )

            let halfLineCount = 7
            let length: Float = 14
            let minorThickness: Float = 0.018
            let majorThickness: Float = 0.034

            for index in -halfLineCount...halfLineCount {
                let offset = Float(index)
                let isMajorLine = index == 0 || index.isMultiple(of: 2)
                let thickness = isMajorLine ? majorThickness : minorThickness
                let material = isMajorLine ? majorLineMaterial : minorLineMaterial

                let xLine = ModelEntity(
                    mesh: .generateBox(size: [length, 0.012, thickness]),
                    materials: [material]
                )
                xLine.position = [0, 0.006, offset]
                floor.addChild(xLine)

                let zLine = ModelEntity(
                    mesh: .generateBox(size: [thickness, 0.012, length]),
                    materials: [material]
                )
                zLine.position = [offset, 0.007, 0]
                floor.addChild(zLine)
            }

            return floor
        }

        private func makeAxisMarkers() -> Entity {
            let axes = Entity()
            axes.name = "DebugAxisMarkers"

            let xMaterial = SimpleMaterial(color: .systemRed, roughness: 0.45, isMetallic: false)
            let zMaterial = SimpleMaterial(color: .systemBlue, roughness: 0.45, isMetallic: false)

            let xAxis = ModelEntity(
                mesh: .generateBox(size: [3.2, 0.06, 0.06]),
                materials: [xMaterial]
            )
            xAxis.position = [1.6, 0.06, 0]
            axes.addChild(xAxis)

            let zAxis = ModelEntity(
                mesh: .generateBox(size: [0.06, 0.06, 3.2]),
                materials: [zMaterial]
            )
            zAxis.position = [0, 0.08, 1.6]
            axes.addChild(zAxis)

            return axes
        }

        private func makeLight() -> DirectionalLight {
            let light = DirectionalLight()
            light.light.color = .white
            light.light.intensity = 1800
            light.look(at: .zero, from: [2, 4, 3], relativeTo: nil)
            return light
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
