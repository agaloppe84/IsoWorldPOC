import simd

public struct FootLockState: Equatable, Hashable, Codable, Sendable {
    public let side: AnimationFootSide
    public let lockedX: Float
    public let lockedY: Float
    public let lockedZ: Float
    public let weight: Float

    public init(side: AnimationFootSide, lockedPosition: SIMD3<Float>, weight: Float) {
        self.side = side
        self.lockedX = lockedPosition.x
        self.lockedY = lockedPosition.y
        self.lockedZ = lockedPosition.z
        self.weight = min(max(weight, 0), 1)
    }

    public var lockedPosition: SIMD3<Float> {
        SIMD3<Float>(lockedX, lockedY, lockedZ)
    }
}

public struct FootIKInput: Equatable, Hashable, Codable, Sendable {
    public let side: AnimationFootSide
    public let animatedFootX: Float
    public let animatedFootY: Float
    public let animatedFootZ: Float
    public let legLength: Float
    public let plantWeight: Float
    public let contactPatch: ContactPatch?
    public let previousLock: FootLockState?

    public init(
        side: AnimationFootSide,
        animatedFootPosition: SIMD3<Float>,
        legLength: Float,
        plantWeight: Float,
        contactPatch: ContactPatch?,
        previousLock: FootLockState? = nil
    ) {
        self.side = side
        self.animatedFootX = animatedFootPosition.x
        self.animatedFootY = animatedFootPosition.y
        self.animatedFootZ = animatedFootPosition.z
        self.legLength = max(legLength, 0.01)
        self.plantWeight = min(max(plantWeight, 0), 1)
        self.contactPatch = contactPatch
        self.previousLock = previousLock
    }

    public var animatedFootPosition: SIMD3<Float> {
        SIMD3<Float>(animatedFootX, animatedFootY, animatedFootZ)
    }
}

public struct FootIKResult: Equatable, Hashable, Codable, Sendable {
    public let side: AnimationFootSide
    public let targetX: Float
    public let targetY: Float
    public let targetZ: Float
    public let normalX: Float
    public let normalY: Float
    public let normalZ: Float
    public let weight: Float
    public let pelvisOffsetY: Float
    public let clearanceLift: Float
    public let slipDistance: Float
    public let lockState: FootLockState?

    public init(
        side: AnimationFootSide,
        target: SIMD3<Float>,
        normal: SIMD3<Float>,
        weight: Float,
        pelvisOffsetY: Float,
        clearanceLift: Float,
        slipDistance: Float,
        lockState: FootLockState?
    ) {
        self.side = side
        self.targetX = target.x
        self.targetY = target.y
        self.targetZ = target.z
        self.normalX = normal.x
        self.normalY = normal.y
        self.normalZ = normal.z
        self.weight = min(max(weight, 0), 1)
        self.pelvisOffsetY = pelvisOffsetY
        self.clearanceLift = max(clearanceLift, 0)
        self.slipDistance = max(slipDistance, 0)
        self.lockState = lockState
    }

    public var target: SIMD3<Float> {
        SIMD3<Float>(targetX, targetY, targetZ)
    }

    public var normal: SIMD3<Float> {
        SIMD3<Float>(normalX, normalY, normalZ)
    }
}

public struct FootIKSolver: Sendable {
    public let soleOffset: Float
    public let maxPelvisCompensation: Float
    public let smallObstacleClearance: Float

    public init(
        soleOffset: Float = 0.018,
        maxPelvisCompensation: Float = 0.18,
        smallObstacleClearance: Float = 0.08
    ) {
        self.soleOffset = max(soleOffset, 0)
        self.maxPelvisCompensation = max(maxPelvisCompensation, 0)
        self.smallObstacleClearance = max(smallObstacleClearance, 0)
    }

    public func solve(_ input: FootIKInput) -> FootIKResult {
        guard let patch = input.contactPatch else {
            return FootIKResult(
                side: input.side,
                target: input.animatedFootPosition,
                normal: SIMD3<Float>(0, 1, 0),
                weight: 0,
                pelvisOffsetY: 0,
                clearanceLift: 0,
                slipDistance: 0,
                lockState: nil
            )
        }

        var target = input.animatedFootPosition
        target.y = patch.centerY + soleOffset

        let clearanceLift = patch.tags.contains(.smallObstacle) && input.plantWeight < 0.5
            ? smallObstacleClearance * (1 - input.plantWeight)
            : 0
        target.y += clearanceLift

        let slipDistance = patch.friction < 0.40 && input.plantWeight > 0.5
            ? (0.40 - patch.friction) * 0.08
            : 0

        if input.plantWeight >= 0.5, let previousLock = input.previousLock {
            let lockBlend = min(max(input.plantWeight + patch.friction * 0.25, 0), 1)
            target = previousLock.lockedPosition + (target - previousLock.lockedPosition) * (1 - lockBlend)
        }

        let verticalError = input.animatedFootY - target.y
        let pelvisOffset = min(max(verticalError * input.plantWeight, -maxPelvisCompensation), maxPelvisCompensation)
        let lockState = input.plantWeight >= 0.5
            ? FootLockState(side: input.side, lockedPosition: target, weight: input.plantWeight)
            : nil

        return FootIKResult(
            side: input.side,
            target: target,
            normal: patch.normal,
            weight: patch.isUsableFootSupport ? input.plantWeight : input.plantWeight * 0.35,
            pelvisOffsetY: pelvisOffset,
            clearanceLift: clearanceLift,
            slipDistance: slipDistance,
            lockState: lockState
        )
    }
}
