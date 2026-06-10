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

    private let targetYOffset: Float = 0.55
    private let lookDeadZone: Float = 0.08
    private let yawSpeed: Float = 1.7
    private let pitchSpeed: Float = 1.1

    var cameraDistance: Float = 8.5
    var cameraYaw: Float = Float.pi * 0.25
    var cameraPitch: Float = 0.56
    let minPitch: Float = 0.26
    let maxPitch: Float = 1.05

    var movementForward: SIMD2<Float> {
        normalized([-sin(cameraYaw), -cos(cameraYaw)])
    }

    var movementRight: SIMD2<Float> {
        normalized([cos(cameraYaw), -sin(cameraYaw)])
    }

    init() {
        camera.camera.fieldOfViewInDegrees = 35
        update(following: .zero)
    }

    func updateOrbit(deltaTime: Float, input: PlayerInputState) {
        let lookX = abs(input.lookX) >= lookDeadZone ? input.lookX : 0
        let lookY = abs(input.lookY) >= lookDeadZone ? input.lookY : 0

        cameraYaw -= lookX * yawSpeed * deltaTime
        cameraPitch = clamped(
            cameraPitch + lookY * pitchSpeed * deltaTime,
            lowerBound: minPitch,
            upperBound: maxPitch
        )
    }

    func update(following playerPosition: SIMD3<Float>) {
        let target = playerPosition + SIMD3<Float>(0, targetYOffset, 0)
        let horizontalDistance = cameraDistance * cos(cameraPitch)
        let height = cameraDistance * sin(cameraPitch)
        let offset = SIMD3<Float>(
            sin(cameraYaw) * horizontalDistance,
            height,
            cos(cameraYaw) * horizontalDistance
        )
        let position = target + offset

        camera.look(at: target, from: position, relativeTo: nil)
    }

    private func normalized(_ vector: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(vector)

        guard length > 0 else {
            return .zero
        }

        return vector / length
    }

    private func clamped(_ value: Float, lowerBound: Float, upperBound: Float) -> Float {
        min(max(value, lowerBound), upperBound)
    }
}
