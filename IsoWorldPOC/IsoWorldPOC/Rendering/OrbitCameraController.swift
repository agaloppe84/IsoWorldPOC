//
//  OrbitCameraController.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import simd

struct OrbitCameraPose {
    let position: SIMD3<Float>
    let target: SIMD3<Float>
    let up: SIMD3<Float>
}

@MainActor
final class OrbitCameraController {
    private let targetYOffset: Float = 0.55
    private let lookDeadZone: Float = 0.08
    private let yawSpeed: Float = 1.7
    private let pitchSpeed: Float = 1.1

    var cameraDistance: Float = 8.5
    var cameraYaw: Float = Float.pi * 0.25
    var cameraPitch: Float = 0.56
    let minPitch: Float = 0.26
    let maxPitch: Float = 1.05
    var fieldOfViewDegrees: Float = 35

    var movementForward: SIMD2<Float> {
        normalized([-sin(cameraYaw), -cos(cameraYaw)])
    }

    var movementRight: SIMD2<Float> {
        normalized([cos(cameraYaw), -sin(cameraYaw)])
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

    func pose(following playerPosition: SIMD3<Float>) -> OrbitCameraPose {
        let target = playerPosition + SIMD3<Float>(0, targetYOffset, 0)
        let horizontalDistance = cameraDistance * cos(cameraPitch)
        let height = cameraDistance * sin(cameraPitch)
        let offset = SIMD3<Float>(
            sin(cameraYaw) * horizontalDistance,
            height,
            cos(cameraYaw) * horizontalDistance
        )

        return OrbitCameraPose(
            position: target + offset,
            target: target,
            up: SIMD3<Float>(0, 1, 0)
        )
    }

    func renderState(following playerPosition: SIMD3<Float>) -> CameraRenderState {
        let pose = pose(following: playerPosition)

        return CameraRenderState(
            position: WorldPosition(x: pose.position.x, y: pose.position.y, z: pose.position.z),
            target: WorldPosition(x: pose.target.x, y: pose.target.y, z: pose.target.z),
            up: PropVector3(x: pose.up.x, y: pose.up.y, z: pose.up.z),
            fieldOfViewDegrees: fieldOfViewDegrees,
            nearClipDistance: 0.05,
            farClipDistance: 160,
            yaw: cameraYaw,
            pitch: cameraPitch,
            distance: cameraDistance
        )
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
