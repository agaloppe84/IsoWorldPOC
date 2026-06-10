//
//  PlayerController.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import simd

struct PlayerController {
    private(set) var position = SIMD3<Float>(0, 0, 0)

    var walkSpeed: Float = 2.2
    var sprintMultiplier: Float = 1.6
    var inputDeadZone: Float = 0.08
    var terrainSurfaceOffset: Float = 0.02

    mutating func update(deltaTime: Float, input: PlayerInputState) -> SIMD3<Float> {
        let proposedPosition = proposedHorizontalPosition(deltaTime: deltaTime, input: input)
        position.x = proposedPosition.x
        position.z = proposedPosition.z

        return position
    }

    func proposedHorizontalPosition(deltaTime: Float, input: PlayerInputState) -> SIMD3<Float> {
        var movement = SIMD2<Float>(input.moveX, input.moveY)

        if simd_length(movement) < inputDeadZone {
            movement = .zero
        } else if simd_length(movement) > 1 {
            movement = simd_normalize(movement)
        }

        let speed = input.sprintPressed ? walkSpeed * sprintMultiplier : walkSpeed
        var proposedPosition = position
        proposedPosition.x += movement.x * speed * deltaTime
        proposedPosition.z -= movement.y * speed * deltaTime

        return proposedPosition
    }

    mutating func applyGroundedPosition(_ groundedPosition: SIMD3<Float>) -> SIMD3<Float> {
        position = groundedPosition

        return position
    }

    mutating func followTerrain(height: Float?) -> SIMD3<Float> {
        if let height {
            position.y = height + terrainSurfaceOffset
        } else {
            position.y = 0
        }

        return position
    }
}
