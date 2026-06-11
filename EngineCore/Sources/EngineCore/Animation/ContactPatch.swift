import simd

public enum ContactPatchTag: String, CaseIterable, Codable, Sendable {
    case flat
    case slope
    case steepSlope
    case water
    case mud
    case snow
    case grass
    case sand
    case rock
    case dirt
    case slippery
    case soft
    case hard
    case smallObstacle
    case climbable
    case blocked
    case noisy
    case stable
    case unstable
}

public struct ContactPatch: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let centerX: Float
    public let centerY: Float
    public let centerZ: Float
    public let normalX: Float
    public let normalY: Float
    public let normalZ: Float
    public let tangentForwardX: Float
    public let tangentForwardY: Float
    public let tangentForwardZ: Float
    public let tangentRightX: Float
    public let tangentRightY: Float
    public let tangentRightZ: Float
    public let area: Float
    public let slopeDegrees: Float
    public let roughness: Float
    public let stability: Float
    public let friction: Float
    public let wetness: Float
    public let compliance: Float
    public let penetrationRisk: Float
    public let edgeDistance: Float
    public let materialKind: TerrainMaterialKind
    public let surfaceClass: TraversalSurfaceClass?
    public let tags: [ContactPatchTag]

    public init(
        id: StableID,
        center: SIMD3<Float>,
        normal: SIMD3<Float>,
        tangentForward: SIMD3<Float>,
        tangentRight: SIMD3<Float>,
        area: Float,
        slopeDegrees: Float,
        roughness: Float,
        stability: Float,
        friction: Float,
        wetness: Float,
        compliance: Float,
        penetrationRisk: Float,
        edgeDistance: Float,
        materialKind: TerrainMaterialKind,
        surfaceClass: TraversalSurfaceClass?,
        tags: [ContactPatchTag]
    ) {
        let normal = Self.normalized(normal, fallback: SIMD3<Float>(0, 1, 0))
        let tangentForward = Self.normalized(tangentForward, fallback: SIMD3<Float>(0, 0, 1))
        let tangentRight = Self.normalized(tangentRight, fallback: SIMD3<Float>(1, 0, 0))

        self.id = id
        self.centerX = center.x
        self.centerY = center.y
        self.centerZ = center.z
        self.normalX = normal.x
        self.normalY = normal.y
        self.normalZ = normal.z
        self.tangentForwardX = tangentForward.x
        self.tangentForwardY = tangentForward.y
        self.tangentForwardZ = tangentForward.z
        self.tangentRightX = tangentRight.x
        self.tangentRightY = tangentRight.y
        self.tangentRightZ = tangentRight.z
        self.area = max(area, 0)
        self.slopeDegrees = max(slopeDegrees, 0)
        self.roughness = Self.clamped01(roughness)
        self.stability = Self.clamped01(stability)
        self.friction = Self.clamped01(friction)
        self.wetness = Self.clamped01(wetness)
        self.compliance = Self.clamped01(compliance)
        self.penetrationRisk = Self.clamped01(penetrationRisk)
        self.edgeDistance = max(edgeDistance, 0)
        self.materialKind = materialKind
        self.surfaceClass = surfaceClass
        self.tags = Array(Set(tags)).sorted { $0.rawValue < $1.rawValue }
    }

    public var center: SIMD3<Float> {
        SIMD3<Float>(centerX, centerY, centerZ)
    }

    public var normal: SIMD3<Float> {
        SIMD3<Float>(normalX, normalY, normalZ)
    }

    public var tangentForward: SIMD3<Float> {
        SIMD3<Float>(tangentForwardX, tangentForwardY, tangentForwardZ)
    }

    public var tangentRight: SIMD3<Float> {
        SIMD3<Float>(tangentRightX, tangentRightY, tangentRightZ)
    }

    public var isUsableFootSupport: Bool {
        stability >= 0.30 && !tags.contains(.blocked)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func normalized(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return fallback
        }

        return vector / length
    }
}
