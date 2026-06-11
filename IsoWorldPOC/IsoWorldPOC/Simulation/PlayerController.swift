//
//  PlayerController.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import EngineCore
import simd

struct PlayerController {
    let characterDNA: CharacterDNA
    private(set) var characterRuntimeState: CharacterRuntimeState
    private(set) var animationSample: AnimationSample
    private(set) var footIKResults: [AnimationFootSide: FootIKResult] = [:]
    private(set) var recentFootstepEvents: [FootstepEvent] = []
    private(set) var motorResult: CharacterMotorResult?
    private(set) var position = SIMD3<Float>(0, 0, 0)

    var walkSpeed: Float
    var sprintMultiplier: Float = 1.6
    var inputDeadZone: Float = 0.08
    var terrainSurfaceOffset: Float = 0.02

    private var animationTime: Float = 0
    private var footLocks: [AnimationFootSide: FootLockState] = [:]
    private var footstepEmitter = FootstepEventEmitter()
    private let animationSampler = AnimationSampler()
    private let footIKSolver = FootIKSolver()
    private let characterMotor = CharacterMotor()

    init(
        position: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        characterDNA: CharacterDNA = CharacterDNA.makePlayer(worldSeed: ProceduralChunkDataFactory.activeSeed)
    ) {
        self.characterDNA = characterDNA
        self.characterRuntimeState = characterDNA.defaultRuntimeState
        self.position = position
        self.walkSpeed = characterDNA.body.naturalWalkSpeedMetersPerSecond
        self.animationSample = AnimationSampler().sample(
            clip: AnimationClip.humanoidIdle(body: characterDNA.body),
            time: 0
        )
    }

    mutating func update(deltaTime: Float, input: PlayerInputState) -> SIMD3<Float> {
        let proposedPosition = proposedHorizontalPosition(
            deltaTime: deltaTime,
            input: input,
            movementRight: [1, 0],
            movementForward: [0, -1]
        )
        position.x = proposedPosition.x
        position.z = proposedPosition.z

        return position
    }

    func proposedHorizontalPosition(
        deltaTime: Float,
        input: PlayerInputState,
        movementRight: SIMD2<Float>,
        movementForward: SIMD2<Float>
    ) -> SIMD3<Float> {
        var movement = SIMD2<Float>(input.moveX, input.moveY)

        if simd_length(movement) < inputDeadZone {
            movement = .zero
        } else if simd_length(movement) > 1 {
            movement = simd_normalize(movement)
        }

        let worldMovement = movementRight * movement.x + movementForward * movement.y
        let speed = input.sprintPressed ? walkSpeed * sprintMultiplier : walkSpeed
        var proposedPosition = position
        proposedPosition.x += worldMovement.x * speed * deltaTime
        proposedPosition.z += worldMovement.y * speed * deltaTime

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

    mutating func updateMotion(
        deltaTime: Float,
        previousPosition: SIMD3<Float>,
        input: PlayerInputState,
        grounding: PlayerGroundingResult
    ) {
        animationTime += max(deltaTime, 0)

        let horizontalDelta = SIMD2<Float>(
            position.x - previousPosition.x,
            position.z - previousPosition.z
        )
        let horizontalSpeed = deltaTime > 0 ? simd_length(horizontalDelta) / deltaTime : 0
        let clip = horizontalSpeed > 0.05
            ? AnimationClip.humanoidWalk(body: characterDNA.body)
            : AnimationClip.humanoidIdle(body: characterDNA.body)
        animationSample = animationSampler.sample(clip: clip, time: animationTime)

        let movementDirection = normalizedOrDefault(horizontalDelta, fallback: SIMD2<Float>(0, -1))
        let movementRight = SIMD2<Float>(movementDirection.y, -movementDirection.x)
        let groundPatch = grounding.groundSample?.contactPatch(worldX: position.x, worldZ: position.z)
        var nextFootIKResults: [AnimationFootSide: FootIKResult] = [:]
        var patchesByFoot: [AnimationFootSide: ContactPatch] = [:]

        for side in AnimationFootSide.allCases {
            let animatedFootPosition = footTargetPosition(
                side: side,
                rootPosition: position,
                movementForward: movementDirection,
                movementRight: movementRight,
                pose: animationSample.pose
            )
            let result = footIKSolver.solve(FootIKInput(
                side: side,
                animatedFootPosition: animatedFootPosition,
                legLength: characterDNA.body.heightMeters * 0.48 * characterDNA.body.legLengthRatio,
                plantWeight: animationSample.footPlantWeights.weight(for: side),
                contactPatch: groundPatch,
                previousLock: footLocks[side]
            ))

            nextFootIKResults[side] = result
            footLocks[side] = result.lockState

            if let groundPatch {
                patchesByFoot[side] = groundPatch
            }
        }

        footIKResults = nextFootIKResults
        recentFootstepEvents = footstepEmitter.events(
            time: animationTime,
            previousPosition: previousPosition,
            currentPosition: position,
            weights: animationSample.footPlantWeights,
            patchesByFoot: patchesByFoot
        )
        motorResult = characterMotor.update(CharacterMotorInput(
            currentPosition: position,
            desiredMove: horizontalDelta,
            deltaTime: deltaTime,
            body: characterDNA.body,
            runtimeState: characterRuntimeState,
            groundPatch: groundPatch,
            sprintRequested: input.sprintPressed
        ))
    }

    var collisionCapsule: CharacterCollisionCapsule {
        characterDNA.body.collisionCapsule
    }

    private func footTargetPosition(
        side: AnimationFootSide,
        rootPosition: SIMD3<Float>,
        movementForward: SIMD2<Float>,
        movementRight: SIMD2<Float>,
        pose: Pose
    ) -> SIMD3<Float> {
        let sideSign: Float = side == .left ? -1 : 1
        let stanceHalfWidth = characterDNA.body.hipWidth * 0.52
        let footPose = pose.joint(side.footJointID)
        let strideOffset = footPose?.localZ ?? 0
        let verticalOffset = footPose?.localY ?? 0
        let x = rootPosition.x +
            movementRight.x * stanceHalfWidth * sideSign +
            movementForward.x * strideOffset
        let z = rootPosition.z +
            movementRight.y * stanceHalfWidth * sideSign +
            movementForward.y * strideOffset

        return SIMD3<Float>(x, rootPosition.y + verticalOffset, z)
    }

    private func normalizedOrDefault(_ vector: SIMD2<Float>, fallback: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return fallback
        }

        return vector / length
    }
}
