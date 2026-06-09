//
//  CameraController.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import RealityKit

@MainActor
final class CameraController {
    let camera = PerspectiveCamera()

    private let targetYOffset: Float = 0.55
    private let followOffset = SIMD3<Float>(3.5, 3.0, 3.5)

    init() {
        camera.camera.fieldOfViewInDegrees = 35
        update(following: .zero)
    }

    func update(following playerPosition: SIMD3<Float>) {
        let target = playerPosition + SIMD3<Float>(0, targetYOffset, 0)
        let position = target + followOffset
        camera.look(at: target, from: position, relativeTo: nil)
    }
}
