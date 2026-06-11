import simd

public struct JointPose: Equatable, Hashable, Codable, Sendable {
    public let jointID: CharacterJointID
    public let localX: Float
    public let localY: Float
    public let localZ: Float
    public let rotationX: Float
    public let rotationY: Float
    public let rotationZ: Float

    public init(
        jointID: CharacterJointID,
        localX: Float,
        localY: Float,
        localZ: Float,
        rotationX: Float = 0,
        rotationY: Float = 0,
        rotationZ: Float = 0
    ) {
        self.jointID = jointID
        self.localX = localX
        self.localY = localY
        self.localZ = localZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
    }

    public init(joint: CharacterJoint) {
        self.init(
            jointID: joint.id,
            localX: joint.localX,
            localY: joint.localY,
            localZ: joint.localZ
        )
    }

    public var translation: SIMD3<Float> {
        SIMD3<Float>(localX, localY, localZ)
    }

    public func offsetBy(x: Float = 0, y: Float = 0, z: Float = 0) -> JointPose {
        JointPose(
            jointID: jointID,
            localX: localX + x,
            localY: localY + y,
            localZ: localZ + z,
            rotationX: rotationX,
            rotationY: rotationY,
            rotationZ: rotationZ
        )
    }

    public func rotatedBy(x: Float = 0, y: Float = 0, z: Float = 0) -> JointPose {
        JointPose(
            jointID: jointID,
            localX: localX,
            localY: localY,
            localZ: localZ,
            rotationX: rotationX + x,
            rotationY: rotationY + y,
            rotationZ: rotationZ + z
        )
    }

    public static func blended(_ first: JointPose, _ second: JointPose, amount: Float) -> JointPose {
        let amount = min(max(amount, 0), 1)

        return JointPose(
            jointID: first.jointID,
            localX: lerp(first.localX, second.localX, amount),
            localY: lerp(first.localY, second.localY, amount),
            localZ: lerp(first.localZ, second.localZ, amount),
            rotationX: lerp(first.rotationX, second.rotationX, amount),
            rotationY: lerp(first.rotationY, second.rotationY, amount),
            rotationZ: lerp(first.rotationZ, second.rotationZ, amount)
        )
    }

    private static func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}

public struct Pose: Equatable, Hashable, Codable, Sendable {
    public let joints: [JointPose]
    public let rootX: Float
    public let rootY: Float
    public let rootZ: Float

    public init(
        joints: [JointPose],
        rootX: Float = 0,
        rootY: Float = 0,
        rootZ: Float = 0
    ) {
        precondition(!joints.isEmpty, "Pose requires joint poses.")
        precondition(Set(joints.map(\.jointID)).count == joints.count, "Pose joint IDs must be unique.")

        self.joints = joints.sorted { $0.jointID.rawValue < $1.jointID.rawValue }
        self.rootX = rootX
        self.rootY = rootY
        self.rootZ = rootZ
    }

    public var rootTranslation: SIMD3<Float> {
        SIMD3<Float>(rootX, rootY, rootZ)
    }

    public func joint(_ id: CharacterJointID) -> JointPose? {
        joints.first { $0.jointID == id }
    }

    public func replacing(_ jointPose: JointPose) -> Pose {
        var updated = joints.filter { $0.jointID != jointPose.jointID }
        updated.append(jointPose)

        return Pose(
            joints: updated,
            rootX: rootX,
            rootY: rootY,
            rootZ: rootZ
        )
    }

    public static func bindPose(skeleton: CharacterHumanoidSkeleton) -> Pose {
        Pose(joints: skeleton.joints.map(JointPose.init(joint:)))
    }

    public static func bindPose(animationSkeleton: AnimationSkeleton) -> Pose {
        Pose(joints: animationSkeleton.joints.map(JointPose.init(joint:)))
    }

    public static func blended(_ first: Pose, _ second: Pose, amount: Float) -> Pose {
        let amount = min(max(amount, 0), 1)
        let secondByID = Dictionary(uniqueKeysWithValues: second.joints.map { ($0.jointID, $0) })
        let blendedJoints = first.joints.map { firstJoint in
            guard let secondJoint = secondByID[firstJoint.jointID] else {
                return firstJoint
            }

            return JointPose.blended(firstJoint, secondJoint, amount: amount)
        }

        return Pose(
            joints: blendedJoints,
            rootX: lerp(first.rootX, second.rootX, amount),
            rootY: lerp(first.rootY, second.rootY, amount),
            rootZ: lerp(first.rootZ, second.rootZ, amount)
        )
    }

    private static func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}
