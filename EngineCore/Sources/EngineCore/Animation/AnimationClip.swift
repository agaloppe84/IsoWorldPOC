import Foundation

public enum AnimationClipID: String, CaseIterable, Codable, Sendable {
    case humanoidIdle
    case humanoidWalk
}

public enum AnimationGait: String, CaseIterable, Codable, Sendable {
    case idle
    case walk
    case carefulWalk
    case run

    public var speedScale: Float {
        switch self {
        case .idle:
            return 0
        case .carefulWalk:
            return 0.56
        case .walk:
            return 1
        case .run:
            return 1.62
        }
    }
}

public struct AnimationFootContactWindow: Equatable, Hashable, Codable, Sendable {
    public let side: AnimationFootSide
    public let startNormalizedTime: Float
    public let endNormalizedTime: Float

    public init(
        side: AnimationFootSide,
        startNormalizedTime: Float,
        endNormalizedTime: Float
    ) {
        self.side = side
        self.startNormalizedTime = Self.normalized(startNormalizedTime)
        self.endNormalizedTime = Self.normalized(endNormalizedTime)
    }

    public func contains(normalizedTime: Float) -> Bool {
        let time = Self.normalized(normalizedTime)

        if startNormalizedTime <= endNormalizedTime {
            return time >= startNormalizedTime && time <= endNormalizedTime
        }

        return time >= startNormalizedTime || time <= endNormalizedTime
    }

    private static func normalized(_ value: Float) -> Float {
        let truncated = value - floor(value)
        return truncated < 0 ? truncated + 1 : truncated
    }
}

public struct AnimationKeyframe: Equatable, Hashable, Codable, Sendable {
    public let time: Float
    public let pose: Pose

    public init(time: Float, pose: Pose) {
        precondition(time >= 0, "Animation keyframe time must be non-negative.")

        self.time = time
        self.pose = pose
    }
}

public struct AnimationClip: Equatable, Hashable, Codable, Sendable {
    public let id: AnimationClipID
    public let duration: Float
    public let gait: AnimationGait
    public let keyframes: [AnimationKeyframe]
    public let contactWindows: [AnimationFootContactWindow]
    public let rootMotionMetersPerCycle: Float

    public init(
        id: AnimationClipID,
        duration: Float,
        gait: AnimationGait,
        keyframes: [AnimationKeyframe],
        contactWindows: [AnimationFootContactWindow] = [],
        rootMotionMetersPerCycle: Float = 0
    ) {
        precondition(duration > 0, "AnimationClip duration must be positive.")
        precondition(!keyframes.isEmpty, "AnimationClip requires keyframes.")

        self.id = id
        self.duration = duration
        self.gait = gait
        self.keyframes = keyframes.sorted { $0.time < $1.time }
        self.contactWindows = contactWindows
        self.rootMotionMetersPerCycle = max(rootMotionMetersPerCycle, 0)
    }

    public func contactWeight(side: AnimationFootSide, normalizedTime: Float) -> Float {
        contactWindows.contains { $0.side == side && $0.contains(normalizedTime: normalizedTime) } ? 1 : 0
    }

    public static func humanoidIdle(body: CharacterBodyParameters) -> AnimationClip {
        let skeleton = body.skeleton
        let pose = Pose.bindPose(skeleton: skeleton)

        return AnimationClip(
            id: .humanoidIdle,
            duration: 1,
            gait: .idle,
            keyframes: [
                AnimationKeyframe(time: 0, pose: pose),
                AnimationKeyframe(time: 1, pose: pose),
            ],
            contactWindows: [
                AnimationFootContactWindow(side: .left, startNormalizedTime: 0, endNormalizedTime: 1),
                AnimationFootContactWindow(side: .right, startNormalizedTime: 0, endNormalizedTime: 1),
            ]
        )
    }

    public static func humanoidWalk(body: CharacterBodyParameters) -> AnimationClip {
        let skeleton = body.skeleton
        let stride = body.naturalStrideMeters
        let footLift = min(max(stride * 0.16, 0.05), 0.16)
        let pelvisDrop = min(max(body.heightMeters * 0.018, 0.018), 0.04)

        return AnimationClip(
            id: .humanoidWalk,
            duration: max(0.42, stride / max(body.naturalWalkSpeedMetersPerSecond, 0.1)),
            gait: .walk,
            keyframes: [
                AnimationKeyframe(time: 0, pose: locomotionPose(
                    skeleton: skeleton,
                    leftFootZ: -stride * 0.24,
                    rightFootZ: stride * 0.24,
                    leftFootY: 0,
                    rightFootY: footLift * 0.4,
                    pelvisY: -pelvisDrop * 0.4
                )),
                AnimationKeyframe(time: 0.25, pose: locomotionPose(
                    skeleton: skeleton,
                    leftFootZ: 0,
                    rightFootZ: 0,
                    leftFootY: 0,
                    rightFootY: footLift,
                    pelvisY: -pelvisDrop
                )),
                AnimationKeyframe(time: 0.50, pose: locomotionPose(
                    skeleton: skeleton,
                    leftFootZ: stride * 0.24,
                    rightFootZ: -stride * 0.24,
                    leftFootY: footLift * 0.4,
                    rightFootY: 0,
                    pelvisY: -pelvisDrop * 0.4
                )),
                AnimationKeyframe(time: 0.75, pose: locomotionPose(
                    skeleton: skeleton,
                    leftFootZ: 0,
                    rightFootZ: 0,
                    leftFootY: footLift,
                    rightFootY: 0,
                    pelvisY: -pelvisDrop
                )),
                AnimationKeyframe(time: 1, pose: locomotionPose(
                    skeleton: skeleton,
                    leftFootZ: -stride * 0.24,
                    rightFootZ: stride * 0.24,
                    leftFootY: 0,
                    rightFootY: footLift * 0.4,
                    pelvisY: -pelvisDrop * 0.4
                )),
            ],
            contactWindows: [
                AnimationFootContactWindow(side: .left, startNormalizedTime: 0.88, endNormalizedTime: 0.46),
                AnimationFootContactWindow(side: .right, startNormalizedTime: 0.38, endNormalizedTime: 0.96),
            ],
            rootMotionMetersPerCycle: stride
        )
    }

    private static func locomotionPose(
        skeleton: CharacterHumanoidSkeleton,
        leftFootZ: Float,
        rightFootZ: Float,
        leftFootY: Float,
        rightFootY: Float,
        pelvisY: Float
    ) -> Pose {
        var pose = Pose.bindPose(skeleton: skeleton)

        if let hips = pose.joint(.hips) {
            pose = pose.replacing(hips.offsetBy(y: pelvisY))
        }

        if let leftFoot = pose.joint(.leftFoot) {
            pose = pose.replacing(leftFoot.offsetBy(y: leftFootY, z: leftFootZ))
        }

        if let rightFoot = pose.joint(.rightFoot) {
            pose = pose.replacing(rightFoot.offsetBy(y: rightFootY, z: rightFootZ))
        }

        return pose
    }
}
