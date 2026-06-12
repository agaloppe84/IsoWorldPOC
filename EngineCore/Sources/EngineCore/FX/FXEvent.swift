import simd

public enum FXEventKind: String, CaseIterable, Codable, Sendable {
    case footstepDust
    case footstepSplash
    case impactSparks
    case footprintDecal
}

public struct FXEvent: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let sourceID: StableID
    public let kind: FXEventKind
    public let definitionID: FXDefinitionID
    public let time: Float
    public let worldX: Float
    public let worldY: Float
    public let worldZ: Float
    public let normalX: Float
    public let normalY: Float
    public let normalZ: Float
    public let materialKind: TerrainMaterialKind
    public let intensity: Float
    public let seed: UInt64

    public init(
        id: StableID,
        sourceID: StableID,
        kind: FXEventKind,
        definitionID: FXDefinitionID,
        time: Float,
        position: SIMD3<Float>,
        normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        materialKind: TerrainMaterialKind,
        intensity: Float,
        seed: UInt64
    ) {
        let normal = Self.normalized(normal)

        self.id = id
        self.sourceID = sourceID
        self.kind = kind
        self.definitionID = definitionID
        self.time = max(time, 0)
        self.worldX = position.x
        self.worldY = position.y
        self.worldZ = position.z
        self.normalX = normal.x
        self.normalY = normal.y
        self.normalZ = normal.z
        self.materialKind = materialKind
        self.intensity = min(max(intensity, 0), 1)
        self.seed = seed
    }

    public var position: SIMD3<Float> {
        SIMD3<Float>(worldX, worldY, worldZ)
    }

    public var normal: SIMD3<Float> {
        SIMD3<Float>(normalX, normalY, normalZ)
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return SIMD3<Float>(0, 1, 0)
        }

        return vector / length
    }
}

public struct FXBillboardParticle: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let definitionID: FXDefinitionID
    public let materialKind: TerrainMaterialKind
    public let worldX: Float
    public let worldY: Float
    public let worldZ: Float
    public let velocityX: Float
    public let velocityY: Float
    public let velocityZ: Float
    public let startColor: FXColor
    public let endColor: FXColor
    public let startSize: Float
    public let endSize: Float
    public let lifetime: Float
    public let age: Float
    public let gravity: Float
    public let seed: UInt64

    public init(
        id: StableID,
        definitionID: FXDefinitionID,
        materialKind: TerrainMaterialKind,
        position: SIMD3<Float>,
        velocity: SIMD3<Float>,
        startColor: FXColor,
        endColor: FXColor,
        startSize: Float,
        endSize: Float,
        lifetime: Float,
        age: Float = 0,
        gravity: Float,
        seed: UInt64
    ) {
        self.id = id
        self.definitionID = definitionID
        self.materialKind = materialKind
        self.worldX = position.x
        self.worldY = position.y
        self.worldZ = position.z
        self.velocityX = velocity.x
        self.velocityY = velocity.y
        self.velocityZ = velocity.z
        self.startColor = startColor
        self.endColor = endColor
        self.startSize = max(startSize, 0)
        self.endSize = max(endSize, 0)
        self.lifetime = max(lifetime, 0.000_1)
        self.age = min(max(age, 0), max(lifetime, 0.000_1))
        self.gravity = gravity
        self.seed = seed
    }

    public var position: SIMD3<Float> {
        SIMD3<Float>(worldX, worldY, worldZ)
    }

    public var velocity: SIMD3<Float> {
        SIMD3<Float>(velocityX, velocityY, velocityZ)
    }

    public var lifeProgress: Float {
        min(max(age / lifetime, 0), 1)
    }

    public var displayColor: FXColor {
        startColor.mixed(with: endColor, amount: lifeProgress)
    }

    public var displaySize: Float {
        startSize + (endSize - startSize) * lifeProgress
    }

    public var isAlive: Bool {
        age < lifetime
    }

    public func advanced(by deltaTime: Float) -> FXBillboardParticle {
        let dt = max(deltaTime, 0)
        let nextAge = age + dt
        let nextVelocity = velocity + SIMD3<Float>(0, gravity * dt, 0)
        let nextPosition = position + nextVelocity * dt

        return FXBillboardParticle(
            id: id,
            definitionID: definitionID,
            materialKind: materialKind,
            position: nextPosition,
            velocity: nextVelocity,
            startColor: startColor,
            endColor: endColor,
            startSize: startSize,
            endSize: endSize,
            lifetime: lifetime,
            age: nextAge,
            gravity: gravity,
            seed: seed
        )
    }
}

public struct FXDecal: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let definitionID: FXDefinitionID
    public let materialKind: TerrainMaterialKind
    public let worldX: Float
    public let worldY: Float
    public let worldZ: Float
    public let normalX: Float
    public let normalY: Float
    public let normalZ: Float
    public let color: FXColor
    public let radius: Float
    public let opacity: Float
    public let rotationRadians: Float
    public let lifetime: Float
    public let age: Float
    public let seed: UInt64

    public init(
        id: StableID,
        definitionID: FXDefinitionID,
        materialKind: TerrainMaterialKind,
        position: SIMD3<Float>,
        normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        color: FXColor,
        radius: Float,
        opacity: Float,
        rotationRadians: Float,
        lifetime: Float,
        age: Float = 0,
        seed: UInt64
    ) {
        let normal = Self.normalized(normal)

        self.id = id
        self.definitionID = definitionID
        self.materialKind = materialKind
        self.worldX = position.x
        self.worldY = position.y
        self.worldZ = position.z
        self.normalX = normal.x
        self.normalY = normal.y
        self.normalZ = normal.z
        self.color = color
        self.radius = max(radius, 0)
        self.opacity = min(max(opacity, 0), 1)
        self.rotationRadians = rotationRadians
        self.lifetime = max(lifetime, 0.000_1)
        self.age = min(max(age, 0), max(lifetime, 0.000_1))
        self.seed = seed
    }

    public var position: SIMD3<Float> {
        SIMD3<Float>(worldX, worldY, worldZ)
    }

    public var normal: SIMD3<Float> {
        SIMD3<Float>(normalX, normalY, normalZ)
    }

    public var lifeProgress: Float {
        min(max(age / lifetime, 0), 1)
    }

    public var displayColor: FXColor {
        color.withAlpha(color.alpha * opacity * (1 - lifeProgress))
    }

    public var isAlive: Bool {
        age < lifetime
    }

    public func advanced(by deltaTime: Float) -> FXDecal {
        FXDecal(
            id: id,
            definitionID: definitionID,
            materialKind: materialKind,
            position: position,
            normal: normal,
            color: color,
            radius: radius,
            opacity: opacity,
            rotationRadians: rotationRadians,
            lifetime: lifetime,
            age: age + max(deltaTime, 0),
            seed: seed
        )
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return SIMD3<Float>(0, 1, 0)
        }

        return vector / length
    }
}

public struct FXFrameSnapshot: Equatable, Codable, Sendable {
    public static let empty = FXFrameSnapshot(
        events: [],
        particles: [],
        decals: [],
        budget: .empty
    )

    public let events: [FXEvent]
    public let particles: [FXBillboardParticle]
    public let decals: [FXDecal]
    public let budget: FXBudgetResult

    public init(
        events: [FXEvent],
        particles: [FXBillboardParticle],
        decals: [FXDecal],
        budget: FXBudgetResult
    ) {
        self.events = events
        self.particles = particles
        self.decals = decals
        self.budget = budget
    }

    public var isEmpty: Bool {
        events.isEmpty && particles.isEmpty && decals.isEmpty
    }
}

public struct FXFrameState: Equatable, Codable, Sendable {
    public private(set) var particles: [FXBillboardParticle]
    public private(set) var decals: [FXDecal]

    public init(
        particles: [FXBillboardParticle] = [],
        decals: [FXDecal] = []
    ) {
        self.particles = particles
        self.decals = decals
    }

    public mutating func advance(deltaTime: Float) {
        particles = particles
            .map { $0.advanced(by: deltaTime) }
            .filter(\.isAlive)
        decals = decals
            .map { $0.advanced(by: deltaTime) }
            .filter(\.isAlive)
    }

    public mutating func merge(
        _ emitted: FXFrameSnapshot,
        budget: FXBudget
    ) -> FXFrameSnapshot {
        particles.append(contentsOf: emitted.particles)
        decals.append(contentsOf: emitted.decals)

        let budgeted = budget.apply(
            events: emitted.events,
            particles: particles,
            decals: decals
        )
        particles = budgeted.particles
        decals = budgeted.decals

        return FXFrameSnapshot(
            events: budgeted.events,
            particles: budgeted.particles,
            decals: budgeted.decals,
            budget: budgeted.result
        )
    }

    public func snapshot(budget: FXBudget) -> FXFrameSnapshot {
        let budgeted = budget.apply(
            events: [],
            particles: particles,
            decals: decals
        )

        return FXFrameSnapshot(
            events: [],
            particles: budgeted.particles,
            decals: budgeted.decals,
            budget: budgeted.result
        )
    }
}
