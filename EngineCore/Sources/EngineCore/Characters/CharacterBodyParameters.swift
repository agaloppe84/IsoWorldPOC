public enum CharacterJointID: String, CaseIterable, Codable, Sendable {
    case root
    case hips
    case spine
    case chest
    case neck
    case head
    case leftShoulder
    case leftElbow
    case leftHand
    case rightShoulder
    case rightElbow
    case rightHand
    case leftHip
    case leftKnee
    case leftFoot
    case rightHip
    case rightKnee
    case rightFoot
}

public struct CharacterJoint: Equatable, Hashable, Codable, Sendable {
    public let id: CharacterJointID
    public let parentID: CharacterJointID?
    public let localX: Float
    public let localY: Float
    public let localZ: Float

    public init(
        id: CharacterJointID,
        parentID: CharacterJointID?,
        localX: Float,
        localY: Float,
        localZ: Float
    ) {
        self.id = id
        self.parentID = parentID
        self.localX = localX
        self.localY = localY
        self.localZ = localZ
    }
}

public struct CharacterHumanoidSkeleton: Equatable, Hashable, Codable, Sendable {
    public let joints: [CharacterJoint]

    public init(joints: [CharacterJoint]) {
        precondition(!joints.isEmpty, "CharacterHumanoidSkeleton requires joints.")
        precondition(Set(joints.map(\.id)).count == joints.count, "Joint IDs must be unique.")

        self.joints = joints
    }

    public func joint(_ id: CharacterJointID) -> CharacterJoint? {
        joints.first { $0.id == id }
    }

    public static func canonical(body: CharacterBodyParameters) -> CharacterHumanoidSkeleton {
        let hipHeight = body.heightMeters * 0.54
        let chestHeight = body.heightMeters * 0.28
        let neckHeight = body.heightMeters * 0.11
        let headHeight = body.heightMeters * 0.10 * body.headScale
        let shoulder = body.shoulderWidth * 0.5
        let hip = body.hipWidth * 0.5
        let upperArm = body.heightMeters * 0.18 * body.armLengthRatio
        let lowerArm = body.heightMeters * 0.17 * body.armLengthRatio
        let upperLeg = body.heightMeters * 0.24 * body.legLengthRatio
        let lowerLeg = body.heightMeters * 0.24 * body.legLengthRatio

        return CharacterHumanoidSkeleton(joints: [
            CharacterJoint(id: .root, parentID: nil, localX: 0, localY: 0, localZ: 0),
            CharacterJoint(id: .hips, parentID: .root, localX: 0, localY: hipHeight, localZ: 0),
            CharacterJoint(id: .spine, parentID: .hips, localX: 0, localY: chestHeight * 0.48, localZ: 0),
            CharacterJoint(id: .chest, parentID: .spine, localX: 0, localY: chestHeight * 0.52, localZ: 0),
            CharacterJoint(id: .neck, parentID: .chest, localX: 0, localY: neckHeight, localZ: 0),
            CharacterJoint(id: .head, parentID: .neck, localX: 0, localY: headHeight, localZ: 0),
            CharacterJoint(id: .leftShoulder, parentID: .chest, localX: -shoulder, localY: 0.03, localZ: 0),
            CharacterJoint(id: .leftElbow, parentID: .leftShoulder, localX: -upperArm, localY: -0.03, localZ: 0),
            CharacterJoint(id: .leftHand, parentID: .leftElbow, localX: -lowerArm, localY: -0.02, localZ: 0),
            CharacterJoint(id: .rightShoulder, parentID: .chest, localX: shoulder, localY: 0.03, localZ: 0),
            CharacterJoint(id: .rightElbow, parentID: .rightShoulder, localX: upperArm, localY: -0.03, localZ: 0),
            CharacterJoint(id: .rightHand, parentID: .rightElbow, localX: lowerArm, localY: -0.02, localZ: 0),
            CharacterJoint(id: .leftHip, parentID: .hips, localX: -hip, localY: -0.02, localZ: 0),
            CharacterJoint(id: .leftKnee, parentID: .leftHip, localX: 0, localY: -upperLeg, localZ: 0),
            CharacterJoint(id: .leftFoot, parentID: .leftKnee, localX: 0, localY: -lowerLeg, localZ: 0.06),
            CharacterJoint(id: .rightHip, parentID: .hips, localX: hip, localY: -0.02, localZ: 0),
            CharacterJoint(id: .rightKnee, parentID: .rightHip, localX: 0, localY: -upperLeg, localZ: 0),
            CharacterJoint(id: .rightFoot, parentID: .rightKnee, localX: 0, localY: -lowerLeg, localZ: 0.06),
        ])
    }
}

public struct CharacterCollisionCapsule: Equatable, Hashable, Codable, Sendable {
    public let height: Float
    public let radius: Float
    public let centerY: Float

    public init(height: Float, radius: Float, centerY: Float) {
        precondition(height > 0, "Capsule height must be positive.")
        precondition(radius > 0, "Capsule radius must be positive.")

        self.height = height
        self.radius = radius
        self.centerY = centerY
    }
}

public struct CharacterBodyParameters: Equatable, Hashable, Codable, Sendable {
    public let heightMeters: Float
    public let shoulderWidth: Float
    public let hipWidth: Float
    public let chestDepth: Float
    public let headScale: Float
    public let legLengthRatio: Float
    public let armLengthRatio: Float
    public let musculature: Float
    public let bodyFat: Float
    public let faceBlend: Float

    public init(
        heightMeters: Float = 1.76,
        shoulderWidth: Float = 0.46,
        hipWidth: Float = 0.34,
        chestDepth: Float = 0.24,
        headScale: Float = 1.0,
        legLengthRatio: Float = 1.0,
        armLengthRatio: Float = 1.0,
        musculature: Float = 0.45,
        bodyFat: Float = 0.28,
        faceBlend: Float = 0.50
    ) {
        self.heightMeters = Self.clamped(heightMeters, 1.45, 2.12)
        self.shoulderWidth = Self.clamped(shoulderWidth, 0.32, 0.72)
        self.hipWidth = Self.clamped(hipWidth, 0.26, 0.62)
        self.chestDepth = Self.clamped(chestDepth, 0.18, 0.42)
        self.headScale = Self.clamped(headScale, 0.86, 1.16)
        self.legLengthRatio = Self.clamped(legLengthRatio, 0.86, 1.14)
        self.armLengthRatio = Self.clamped(armLengthRatio, 0.88, 1.16)
        self.musculature = Self.clamped01(musculature)
        self.bodyFat = Self.clamped01(bodyFat)
        self.faceBlend = Self.clamped01(faceBlend)
    }

    public var skeleton: CharacterHumanoidSkeleton {
        CharacterHumanoidSkeleton.canonical(body: self)
    }

    public var sockets: [CharacterSocketDefinition] {
        CharacterSocketDefinition.canonical(body: self)
    }

    public var collisionCapsule: CharacterCollisionCapsule {
        let radius = max(shoulderWidth * 0.38 + bodyFat * 0.035, 0.20)
        let height = max(heightMeters * 0.94, radius * 2.6)
        return CharacterCollisionCapsule(height: height, radius: radius, centerY: height * 0.5)
    }

    public var cameraHeightMeters: Float {
        heightMeters * 0.88
    }

    public var naturalStrideMeters: Float {
        heightMeters * 0.42 * legLengthRatio
    }

    public var naturalWalkSpeedMetersPerSecond: Float {
        let buildPenalty = bodyFat * 0.12
        let strengthBonus = musculature * 0.10
        return max(1.1, heightMeters * (1.24 + strengthBonus - buildPenalty))
    }

    public var handReachMeters: Float {
        heightMeters * 0.43 * armLengthRatio
    }

    public static func makePlayerBody(random: inout StableRNG) -> CharacterBodyParameters {
        CharacterBodyParameters(
            heightMeters: random.nextFloat(in: 1.62...1.94),
            shoulderWidth: random.nextFloat(in: 0.40...0.58),
            hipWidth: random.nextFloat(in: 0.31...0.46),
            chestDepth: random.nextFloat(in: 0.21...0.32),
            headScale: random.nextFloat(in: 0.94...1.07),
            legLengthRatio: random.nextFloat(in: 0.94...1.08),
            armLengthRatio: random.nextFloat(in: 0.95...1.09),
            musculature: random.nextFloat(in: 0.25...0.75),
            bodyFat: random.nextFloat(in: 0.12...0.45),
            faceBlend: random.nextFloat(in: 0...1)
        )
    }

    private static func clamped(_ value: Float, _ lowerBound: Float, _ upperBound: Float) -> Float {
        min(max(value, lowerBound), upperBound)
    }

    private static func clamped01(_ value: Float) -> Float {
        clamped(value, 0, 1)
    }
}
