import simd

public struct CharacterMotorInput: Equatable, Hashable, Codable, Sendable {
    public let currentX: Float
    public let currentY: Float
    public let currentZ: Float
    public let desiredMoveX: Float
    public let desiredMoveZ: Float
    public let deltaTime: Float
    public let body: CharacterBodyParameters
    public let runtimeState: CharacterRuntimeState
    public let groundPatch: ContactPatch?
    public let sprintRequested: Bool

    public init(
        currentPosition: SIMD3<Float>,
        desiredMove: SIMD2<Float>,
        deltaTime: Float,
        body: CharacterBodyParameters,
        runtimeState: CharacterRuntimeState,
        groundPatch: ContactPatch?,
        sprintRequested: Bool = false
    ) {
        self.currentX = currentPosition.x
        self.currentY = currentPosition.y
        self.currentZ = currentPosition.z
        self.desiredMoveX = desiredMove.x
        self.desiredMoveZ = desiredMove.y
        self.deltaTime = max(deltaTime, 0)
        self.body = body
        self.runtimeState = runtimeState
        self.groundPatch = groundPatch
        self.sprintRequested = sprintRequested
    }

    public var currentPosition: SIMD3<Float> {
        SIMD3<Float>(currentX, currentY, currentZ)
    }

    public var desiredMove: SIMD2<Float> {
        SIMD2<Float>(desiredMoveX, desiredMoveZ)
    }
}

public struct CharacterMotorResult: Equatable, Hashable, Codable, Sendable {
    public let positionX: Float
    public let positionY: Float
    public let positionZ: Float
    public let velocityX: Float
    public let velocityY: Float
    public let velocityZ: Float
    public let grounded: Bool
    public let effectiveFriction: Float
    public let speedScale: Float
    public let movementBlocked: Bool
    public let sliding: Bool
    public let stepDeltaY: Float

    public init(
        position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        grounded: Bool,
        effectiveFriction: Float,
        speedScale: Float,
        movementBlocked: Bool,
        sliding: Bool,
        stepDeltaY: Float
    ) {
        self.positionX = position.x
        self.positionY = position.y
        self.positionZ = position.z
        self.velocityX = velocity.x
        self.velocityY = velocity.y
        self.velocityZ = velocity.z
        self.grounded = grounded
        self.effectiveFriction = min(max(effectiveFriction, 0), 1)
        self.speedScale = max(speedScale, 0)
        self.movementBlocked = movementBlocked
        self.sliding = sliding
        self.stepDeltaY = stepDeltaY
    }

    public var position: SIMD3<Float> {
        SIMD3<Float>(positionX, positionY, positionZ)
    }

    public var velocity: SIMD3<Float> {
        SIMD3<Float>(velocityX, velocityY, velocityZ)
    }
}

public struct CharacterMotor: Sendable {
    public let surfaceOffset: Float
    public let maxStepUpMeters: Float
    public let snapToGroundMeters: Float

    public init(
        surfaceOffset: Float = 0.02,
        maxStepUpMeters: Float = 0.34,
        snapToGroundMeters: Float = 0.55
    ) {
        self.surfaceOffset = max(surfaceOffset, 0)
        self.maxStepUpMeters = max(maxStepUpMeters, 0)
        self.snapToGroundMeters = max(snapToGroundMeters, 0)
    }

    public func update(_ input: CharacterMotorInput) -> CharacterMotorResult {
        let currentPosition = input.currentPosition
        let desiredMove = normalized(input.desiredMove)
        let patch = input.groundPatch
        let grounded = patch != nil
        let friction = patch?.friction ?? 0.72
        let surfaceSpeedScale = speedScale(
            stance: input.runtimeState.movementStance,
            friction: friction,
            slopeDegrees: patch?.slopeDegrees ?? 0,
            sprintRequested: input.sprintRequested
        )
        let targetSpeed = input.body.naturalWalkSpeedMetersPerSecond * surfaceSpeedScale
        var velocity = SIMD3<Float>(
            desiredMove.x * targetSpeed,
            0,
            desiredMove.y * targetSpeed
        )
        let currentGroundY = patch.map { $0.centerY + surfaceOffset }
        let stepDeltaY = currentGroundY.map { $0 - currentPosition.y } ?? 0
        let movementBlocked = patch.map { contactPatch in
            contactPatch.tags.contains(.blocked) ||
                (!contactPatch.isUsableFootSupport && contactPatch.slopeDegrees >= 55) ||
                stepDeltaY > maxStepUpMeters
        } ?? false

        if movementBlocked {
            velocity.x = 0
            velocity.z = 0
        }

        var nextPosition = currentPosition + velocity * input.deltaTime

        if let currentGroundY, abs(stepDeltaY) <= max(maxStepUpMeters, snapToGroundMeters) {
            nextPosition.y = currentGroundY
        }

        let slide = slideVelocity(on: patch)
        if simd_length(slide) > 0 {
            velocity.x += slide.x
            velocity.z += slide.y
            nextPosition.x += slide.x * input.deltaTime
            nextPosition.z += slide.y * input.deltaTime
        }

        return CharacterMotorResult(
            position: nextPosition,
            velocity: velocity,
            grounded: grounded,
            effectiveFriction: friction,
            speedScale: surfaceSpeedScale,
            movementBlocked: movementBlocked,
            sliding: simd_length(slide) > 0,
            stepDeltaY: stepDeltaY
        )
    }

    private func speedScale(
        stance: CharacterMovementStance,
        friction: Float,
        slopeDegrees: Float,
        sprintRequested: Bool
    ) -> Float {
        let stanceScale: Float
        switch stance {
        case .standing:
            stanceScale = sprintRequested ? 1.60 : 1
        case .crouching:
            stanceScale = 0.46
        case .climbing:
            stanceScale = 0.28
        case .swimming:
            stanceScale = 0.38
        }

        let frictionScale = 0.52 + min(max(friction, 0), 1) * 0.48
        let slopeScale = max(0.42, 1 - slopeDegrees / 95)

        return stanceScale * frictionScale * slopeScale
    }

    private func slideVelocity(on patch: ContactPatch?) -> SIMD2<Float> {
        guard let patch,
              patch.friction < 0.36,
              patch.slopeDegrees > 14
        else {
            return .zero
        }

        let horizontalNormal = SIMD2<Float>(patch.normalX, patch.normalZ)
        let length = simd_length(horizontalNormal)

        guard length > 0.0001 else {
            return .zero
        }

        let downhill = -horizontalNormal / length
        let strength = (0.36 - patch.friction) * min(patch.slopeDegrees / 45, 1)

        return downhill * strength
    }

    private func normalized(_ vector: SIMD2<Float>) -> SIMD2<Float> {
        let length = simd_length(vector)

        guard length > 1 else {
            return vector
        }

        return vector / length
    }
}
