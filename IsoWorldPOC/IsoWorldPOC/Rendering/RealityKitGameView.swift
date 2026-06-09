//
//  RealityKitGameView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import RealityKit
import SwiftUI

struct RealityKitGameView: NSViewRepresentable {
    func makeNSView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        configureScene(in: arView)
        return arView
    }

    func updateNSView(_ nsView: ARView, context: Context) {}

    private func configureScene(in arView: ARView) {
        arView.scene.anchors.removeAll()

        let worldAnchor = AnchorEntity(world: .zero)
        worldAnchor.addChild(makeCenterCube())
        worldAnchor.addChild(makeLight())
        worldAnchor.addChild(CameraController().makeCamera())

        arView.scene.addAnchor(worldAnchor)
    }

    private func makeCenterCube() -> ModelEntity {
        let material = SimpleMaterial(
            color: .systemTeal,
            roughness: 0.55,
            isMetallic: false
        )
        let cube = ModelEntity(
            mesh: .generateBox(size: 0.8, cornerRadius: 0.04),
            materials: [material]
        )
        cube.position = [0, 0.4, 0]
        return cube
    }

    private func makeLight() -> DirectionalLight {
        let light = DirectionalLight()
        light.light.color = .white
        light.light.intensity = 1800
        light.look(at: .zero, from: [2, 4, 3], relativeTo: nil)
        return light
    }
}

