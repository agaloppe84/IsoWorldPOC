//
//  CameraController.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import RealityKit
import simd

@MainActor
final class CameraController {
    let camera = PerspectiveCamera()
    private let orbit = OrbitCameraController()

    var cameraDistance: Float {
        orbit.cameraDistance
    }

    var cameraYaw: Float {
        orbit.cameraYaw
    }

    var cameraPitch: Float {
        orbit.cameraPitch
    }

    var movementForward: SIMD2<Float> {
        orbit.movementForward
    }

    var movementRight: SIMD2<Float> {
        orbit.movementRight
    }

    init() {
        camera.camera.fieldOfViewInDegrees = orbit.fieldOfViewDegrees
        update(following: .zero)
    }

    func updateOrbit(deltaTime: Float, input: PlayerInputState) {
        orbit.updateOrbit(deltaTime: deltaTime, input: input)
    }

    func update(following playerPosition: SIMD3<Float>) {
        let pose = orbit.pose(following: playerPosition)

        camera.look(at: pose.target, from: pose.position, relativeTo: nil)
    }
}
