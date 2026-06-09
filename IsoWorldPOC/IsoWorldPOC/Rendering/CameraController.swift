//
//  CameraController.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import RealityKit

@MainActor
struct CameraController {
    var target = SIMD3<Float>(0, 0.35, 0)
    var position = SIMD3<Float>(3.5, 3.0, 3.5)

    func makeCamera() -> PerspectiveCamera {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 35
        camera.look(at: target, from: position, relativeTo: nil)
        return camera
    }
}

