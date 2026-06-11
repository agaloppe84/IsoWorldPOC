public enum AnimationFootSide: String, CaseIterable, Codable, Sendable {
    case left
    case right

    public var footJointID: CharacterJointID {
        switch self {
        case .left:
            return .leftFoot
        case .right:
            return .rightFoot
        }
    }

    public var hipJointID: CharacterJointID {
        switch self {
        case .left:
            return .leftHip
        case .right:
            return .rightHip
        }
    }
}

public struct AnimationFootPlantWeights: Equatable, Hashable, Codable, Sendable {
    public let left: Float
    public let right: Float

    public init(left: Float = 0, right: Float = 0) {
        self.left = Self.clamped01(left)
        self.right = Self.clamped01(right)
    }

    public func weight(for side: AnimationFootSide) -> Float {
        switch side {
        case .left:
            return left
        case .right:
            return right
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct AnimationSkeletonRoleMap: Equatable, Hashable, Codable, Sendable {
    public let root: CharacterJointID
    public let pelvis: CharacterJointID
    public let spine: [CharacterJointID]
    public let head: CharacterJointID
    public let leftFoot: CharacterJointID
    public let rightFoot: CharacterJointID

    public init(
        root: CharacterJointID = .root,
        pelvis: CharacterJointID = .hips,
        spine: [CharacterJointID] = [.spine, .chest, .neck],
        head: CharacterJointID = .head,
        leftFoot: CharacterJointID = .leftFoot,
        rightFoot: CharacterJointID = .rightFoot
    ) {
        self.root = root
        self.pelvis = pelvis
        self.spine = spine
        self.head = head
        self.leftFoot = leftFoot
        self.rightFoot = rightFoot
    }
}

public struct AnimationSkeleton: Equatable, Hashable, Codable, Sendable {
    public let joints: [CharacterJoint]
    public let roleMap: AnimationSkeletonRoleMap

    public init(
        joints: [CharacterJoint],
        roleMap: AnimationSkeletonRoleMap = AnimationSkeletonRoleMap()
    ) {
        precondition(!joints.isEmpty, "AnimationSkeleton requires joints.")
        precondition(Set(joints.map(\.id)).count == joints.count, "AnimationSkeleton joint IDs must be unique.")

        self.joints = joints
        self.roleMap = roleMap
    }

    public init(characterSkeleton: CharacterHumanoidSkeleton) {
        self.init(joints: characterSkeleton.joints)
    }

    public func joint(_ id: CharacterJointID) -> CharacterJoint? {
        joints.first { $0.id == id }
    }

    public func index(of id: CharacterJointID) -> Int? {
        joints.firstIndex { $0.id == id }
    }
}
