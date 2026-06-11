import simd

public struct SurfaceMaterialContactProfile: Equatable, Hashable, Codable, Sendable {
    public let materialKind: TerrainMaterialKind
    public let baseFriction: Float
    public let wetFrictionMultiplier: Float
    public let compliance: Float
    public let noiseLevel: Float

    public init(
        materialKind: TerrainMaterialKind,
        baseFriction: Float,
        wetFrictionMultiplier: Float,
        compliance: Float,
        noiseLevel: Float
    ) {
        self.materialKind = materialKind
        self.baseFriction = Self.clamped01(baseFriction)
        self.wetFrictionMultiplier = Self.clamped01(wetFrictionMultiplier)
        self.compliance = Self.clamped01(compliance)
        self.noiseLevel = Self.clamped01(noiseLevel)
    }

    public static func profile(for materialKind: TerrainMaterialKind) -> SurfaceMaterialContactProfile {
        switch materialKind {
        case .grass:
            return SurfaceMaterialContactProfile(
                materialKind: materialKind,
                baseFriction: 0.76,
                wetFrictionMultiplier: 0.72,
                compliance: 0.20,
                noiseLevel: 0.36
            )
        case .rock:
            return SurfaceMaterialContactProfile(
                materialKind: materialKind,
                baseFriction: 0.82,
                wetFrictionMultiplier: 0.64,
                compliance: 0.04,
                noiseLevel: 0.64
            )
        case .dirt:
            return SurfaceMaterialContactProfile(
                materialKind: materialKind,
                baseFriction: 0.72,
                wetFrictionMultiplier: 0.58,
                compliance: 0.22,
                noiseLevel: 0.48
            )
        case .sand:
            return SurfaceMaterialContactProfile(
                materialKind: materialKind,
                baseFriction: 0.56,
                wetFrictionMultiplier: 0.78,
                compliance: 0.50,
                noiseLevel: 0.30
            )
        case .mud:
            return SurfaceMaterialContactProfile(
                materialKind: materialKind,
                baseFriction: 0.42,
                wetFrictionMultiplier: 0.46,
                compliance: 0.72,
                noiseLevel: 0.42
            )
        case .snow:
            return SurfaceMaterialContactProfile(
                materialKind: materialKind,
                baseFriction: 0.38,
                wetFrictionMultiplier: 0.66,
                compliance: 0.62,
                noiseLevel: 0.22
            )
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct SurfaceContactResolver: Sendable {
    public init() {}

    public func patch(
        for sample: TerrainSample,
        worldX: Float,
        worldZ: Float,
        coordinate: ChunkCoordinate? = nil,
        surfaceClass: TraversalSurfaceClass? = nil,
        footprintRadius: Float = 0.16
    ) -> ContactPatch {
        let materialKind = sample.materialWeights.primaryLayer.materialKind
        let profile = SurfaceMaterialContactProfile.profile(for: materialKind)
        let slopeDegrees = TraversalSurfaceClass.slopeDegrees(for: sample.slope)
        let wetness = clamped01(max(sample.moisture, sample.waterDepth * 2.2, sample.featureMasks.water))
        let slopeModifier = max(0.35, 1 - slopeDegrees / 92)
        let wetModifier = 1 - wetness * (1 - profile.wetFrictionMultiplier)
        let friction = clamped01(profile.baseFriction * wetModifier * slopeModifier)
        let resolvedSurfaceClass = surfaceClass ?? TraversalSurfaceClass.classify(sample)
        let stability = stabilityScore(
            sample: sample,
            surfaceClass: resolvedSurfaceClass,
            friction: friction,
            slopeDegrees: slopeDegrees
        )
        let compliance = clamped01(profile.compliance + wetness * 0.18 + sample.featureMasks.water * 0.18)
        let penetrationRisk = clamped01((1 - sample.walkability) * 0.45 + sample.roughness * 0.25 + wetness * 0.18)
        let normal = normalized(sample.normal, fallback: SIMD3<Float>(0, 1, 0))
        let tangentForward = tangent(for: normal)
        let tangentRight = normalized(simd_cross(tangentForward, normal), fallback: SIMD3<Float>(1, 0, 0))

        return ContactPatch(
            id: contactID(
                sample: sample,
                worldX: worldX,
                worldZ: worldZ,
                coordinate: coordinate,
                materialKind: materialKind
            ),
            center: SIMD3<Float>(worldX, sample.height, worldZ),
            normal: normal,
            tangentForward: tangentForward,
            tangentRight: tangentRight,
            area: Float.pi * footprintRadius * footprintRadius,
            slopeDegrees: slopeDegrees,
            roughness: sample.roughness,
            stability: stability,
            friction: friction,
            wetness: wetness,
            compliance: compliance,
            penetrationRisk: penetrationRisk,
            edgeDistance: max(0.02, (1 - sample.curvature) * footprintRadius * 3),
            materialKind: materialKind,
            surfaceClass: resolvedSurfaceClass,
            tags: tags(
                sample: sample,
                materialKind: materialKind,
                surfaceClass: resolvedSurfaceClass,
                slopeDegrees: slopeDegrees,
                friction: friction,
                wetness: wetness,
                compliance: compliance,
                stability: stability
            )
        )
    }

    private func stabilityScore(
        sample: TerrainSample,
        surfaceClass: TraversalSurfaceClass,
        friction: Float,
        slopeDegrees: Float
    ) -> Float {
        var score = sample.walkability * 0.42 +
            friction * 0.24 +
            (1 - sample.roughness) * 0.14 +
            (1 - min(slopeDegrees / 78, 1)) * 0.20

        switch surfaceClass {
        case .walkable:
            score += 0.12
        case .steep:
            score -= 0.08
        case .climbable:
            score -= 0.12
        case .dangerous:
            score -= 0.34
        case .blocked:
            score -= 0.54
        }

        return clamped01(score)
    }

    private func tags(
        sample: TerrainSample,
        materialKind: TerrainMaterialKind,
        surfaceClass: TraversalSurfaceClass,
        slopeDegrees: Float,
        friction: Float,
        wetness: Float,
        compliance: Float,
        stability: Float
    ) -> [ContactPatchTag] {
        var tags: [ContactPatchTag] = []

        switch materialKind {
        case .grass:
            tags.append(.grass)
        case .rock:
            tags.append(.rock)
        case .dirt:
            tags.append(.dirt)
        case .sand:
            tags.append(.sand)
        case .mud:
            tags.append(.mud)
        case .snow:
            tags.append(.snow)
        }

        if slopeDegrees < 8 {
            tags.append(.flat)
        } else if slopeDegrees < 34 {
            tags.append(.slope)
        } else {
            tags.append(.steepSlope)
        }

        if wetness >= 0.55 || sample.waterDepth > 0 {
            tags.append(.water)
        }

        if friction < 0.42 {
            tags.append(.slippery)
        }

        if compliance > 0.46 {
            tags.append(.soft)
        } else {
            tags.append(.hard)
        }

        if sample.roughness >= 0.62 || sample.curvature >= 0.42 {
            tags.append(.smallObstacle)
        }

        if surfaceClass.supportsVerticalTraversal {
            tags.append(.climbable)
        }

        if surfaceClass.isBlockedForFootTraversal {
            tags.append(.blocked)
        }

        if SurfaceMaterialContactProfile.profile(for: materialKind).noiseLevel >= 0.50 {
            tags.append(.noisy)
        }

        tags.append(stability >= 0.55 ? .stable : .unstable)

        return tags
    }

    private func contactID(
        sample: TerrainSample,
        worldX: Float,
        worldZ: Float,
        coordinate: ChunkCoordinate?,
        materialKind: TerrainMaterialKind
    ) -> StableID {
        StableID(StableHash.make { builder in
            builder.combine(SeedDomain.animation)
            if let coordinate {
                builder.combine(coordinate)
            }
            builder.combine(sample.localX)
            builder.combine(sample.localZ)
            builder.combine(worldX)
            builder.combine(worldZ)
            builder.combine(sample.height)
            builder.combine(materialKind.rawValue)
        }.value)
    }

    private func tangent(for normal: SIMD3<Float>) -> SIMD3<Float> {
        let projectedForward = SIMD3<Float>(0, 0, 1) - normal * simd_dot(normal, SIMD3<Float>(0, 0, 1))

        if simd_length(projectedForward) > 0.0001 {
            return simd_normalize(projectedForward)
        }

        return SIMD3<Float>(1, 0, 0)
    }

    private func normalized(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return fallback
        }

        return vector / length
    }

    private func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
