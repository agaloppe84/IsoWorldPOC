import simd

public enum FootstepEventKind: String, CaseIterable, Codable, Sendable {
    case heelStrike
    case toeOff
    case slide
}

public struct FootstepEvent: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: FootstepEventKind
    public let side: AnimationFootSide
    public let time: Float
    public let worldX: Float
    public let worldY: Float
    public let worldZ: Float
    public let materialKind: TerrainMaterialKind
    public let friction: Float
    public let wetness: Float
    public let intensity: Float

    public init(
        id: StableID,
        kind: FootstepEventKind,
        side: AnimationFootSide,
        time: Float,
        position: SIMD3<Float>,
        materialKind: TerrainMaterialKind,
        friction: Float,
        wetness: Float,
        intensity: Float
    ) {
        self.id = id
        self.kind = kind
        self.side = side
        self.time = max(time, 0)
        self.worldX = position.x
        self.worldY = position.y
        self.worldZ = position.z
        self.materialKind = materialKind
        self.friction = min(max(friction, 0), 1)
        self.wetness = min(max(wetness, 0), 1)
        self.intensity = min(max(intensity, 0), 1)
    }

    public var position: SIMD3<Float> {
        SIMD3<Float>(worldX, worldY, worldZ)
    }
}

public struct FootstepEventEmitter: Equatable, Hashable, Codable, Sendable {
    private var previousWeights = AnimationFootPlantWeights()
    private var eventCounter: UInt64 = 0

    public init() {}

    public mutating func events(
        time: Float,
        previousPosition: SIMD3<Float>,
        currentPosition: SIMD3<Float>,
        weights: AnimationFootPlantWeights,
        patchesByFoot: [AnimationFootSide: ContactPatch]
    ) -> [FootstepEvent] {
        let speed = simd_length(SIMD2<Float>(
            currentPosition.x - previousPosition.x,
            currentPosition.z - previousPosition.z
        ))
        var emitted: [FootstepEvent] = []

        for side in AnimationFootSide.allCases {
            let previousWeight = previousWeights.weight(for: side)
            let currentWeight = weights.weight(for: side)

            guard previousWeight < 0.5, currentWeight >= 0.5, let patch = patchesByFoot[side] else {
                continue
            }

            emitted.append(FootstepEvent(
                id: eventID(time: time, side: side, patch: patch),
                kind: patch.friction < 0.36 ? .slide : .heelStrike,
                side: side,
                time: time,
                position: patch.center,
                materialKind: patch.materialKind,
                friction: patch.friction,
                wetness: patch.wetness,
                intensity: min(max(speed * 2.2 + (1 - patch.compliance) * 0.25, 0.15), 1)
            ))
        }

        previousWeights = weights
        return emitted
    }

    private mutating func eventID(
        time: Float,
        side: AnimationFootSide,
        patch: ContactPatch
    ) -> StableID {
        eventCounter &+= 1

        return StableID(StableHash.make { builder in
            builder.combine(SeedDomain.animation)
            builder.combine("footstep")
            builder.combine(eventCounter)
            builder.combine(time)
            builder.combine(side.rawValue)
            builder.combine(patch.id.rawValue)
        }.value)
    }
}
