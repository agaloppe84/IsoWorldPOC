import simd

public struct AudioSurfaceInfo: Equatable, Hashable, Codable, Sendable {
    public let materialKind: TerrainMaterialKind
    public let wetness: Float
    public let friction: Float
    public let hardness: Float
    public let roughness: Float
    public let porosity: Float
    public let crunch: Float
    public let splash: Float
    public let squish: Float
    public let slope: Float
    public let normalX: Float
    public let normalY: Float
    public let normalZ: Float

    public init(
        materialKind: TerrainMaterialKind,
        wetness: Float,
        friction: Float,
        hardness: Float,
        roughness: Float,
        porosity: Float,
        crunch: Float,
        splash: Float,
        squish: Float,
        slope: Float = 0,
        normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    ) {
        let normal = Self.normalized(normal)

        self.materialKind = materialKind
        self.wetness = Self.clamped01(wetness)
        self.friction = Self.clamped01(friction)
        self.hardness = Self.clamped01(hardness)
        self.roughness = Self.clamped01(roughness)
        self.porosity = Self.clamped01(porosity)
        self.crunch = Self.clamped01(crunch)
        self.splash = Self.clamped01(splash)
        self.squish = Self.clamped01(squish)
        self.slope = max(slope, 0)
        self.normalX = normal.x
        self.normalY = normal.y
        self.normalZ = normal.z
    }

    public var normal: SIMD3<Float> {
        SIMD3<Float>(normalX, normalY, normalZ)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return SIMD3<Float>(0, 1, 0)
        }

        return vector / length
    }
}

public struct AudioSurfaceResponse: Equatable, Hashable, Codable, Sendable {
    public let materialKind: TerrainMaterialKind
    public let profileID: String
    public let gainScale: Float
    public let pitchOffsetCents: Float
    public let hardness: Float
    public let roughness: Float
    public let porosity: Float
    public let crunch: Float
    public let splash: Float
    public let squish: Float
    public let lowResonance: Float
    public let highSparkle: Float

    public init(
        materialKind: TerrainMaterialKind,
        profileID: String,
        gainScale: Float,
        pitchOffsetCents: Float,
        hardness: Float,
        roughness: Float,
        porosity: Float,
        crunch: Float,
        splash: Float,
        squish: Float,
        lowResonance: Float,
        highSparkle: Float
    ) {
        self.materialKind = materialKind
        self.profileID = profileID
        self.gainScale = max(gainScale, 0)
        self.pitchOffsetCents = pitchOffsetCents
        self.hardness = Self.clamped01(hardness)
        self.roughness = Self.clamped01(roughness)
        self.porosity = Self.clamped01(porosity)
        self.crunch = Self.clamped01(crunch)
        self.splash = Self.clamped01(splash)
        self.squish = Self.clamped01(squish)
        self.lowResonance = Self.clamped01(lowResonance)
        self.highSparkle = Self.clamped01(highSparkle)
    }

    public func surfaceInfo(
        wetness: Float,
        friction: Float,
        slope: Float = 0,
        normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0)
    ) -> AudioSurfaceInfo {
        AudioSurfaceInfo(
            materialKind: materialKind,
            wetness: wetness,
            friction: friction,
            hardness: hardness,
            roughness: roughness,
            porosity: porosity,
            crunch: crunch,
            splash: splash,
            squish: squish,
            slope: slope,
            normal: normal
        )
    }

    public static func response(
        for materialKind: TerrainMaterialKind,
        wetness: Float,
        friction: Float
    ) -> AudioSurfaceResponse {
        let wetness = clamped01(wetness)
        let friction = clamped01(friction)

        switch materialKind {
        case .grass:
            return AudioSurfaceResponse(
                materialKind: .grass,
                profileID: "surface.grass.soft",
                gainScale: 0.72 + friction * 0.18,
                pitchOffsetCents: -30,
                hardness: 0.22,
                roughness: 0.48,
                porosity: 0.58,
                crunch: 0.25,
                splash: wetness * 0.35,
                squish: wetness * 0.20,
                lowResonance: 0.18,
                highSparkle: 0.32
            )
        case .rock:
            return AudioSurfaceResponse(
                materialKind: .rock,
                profileID: "surface.rock.hard",
                gainScale: 0.92 + friction * 0.20,
                pitchOffsetCents: 80,
                hardness: 0.92,
                roughness: 0.62,
                porosity: 0.12,
                crunch: 0.58,
                splash: wetness * 0.12,
                squish: 0,
                lowResonance: 0.38,
                highSparkle: 0.76
            )
        case .dirt:
            return AudioSurfaceResponse(
                materialKind: .dirt,
                profileID: "surface.dirt.grain",
                gainScale: 0.82 + friction * 0.16,
                pitchOffsetCents: -10,
                hardness: 0.42,
                roughness: 0.72,
                porosity: 0.68,
                crunch: 0.42 * (1 - wetness * 0.45),
                splash: wetness * 0.45,
                squish: wetness * 0.28,
                lowResonance: 0.28,
                highSparkle: 0.44
            )
        case .sand:
            return AudioSurfaceResponse(
                materialKind: .sand,
                profileID: "surface.sand.soft-grain",
                gainScale: 0.70 + friction * 0.12,
                pitchOffsetCents: -55,
                hardness: 0.18,
                roughness: 0.88,
                porosity: 0.86,
                crunch: 0.62 * (1 - wetness * 0.30),
                splash: wetness * 0.22,
                squish: wetness * 0.12,
                lowResonance: 0.12,
                highSparkle: 0.56
            )
        case .mud:
            return AudioSurfaceResponse(
                materialKind: .mud,
                profileID: "surface.mud.wet-suction",
                gainScale: 0.76 + wetness * 0.28,
                pitchOffsetCents: -95,
                hardness: 0.10,
                roughness: 0.66,
                porosity: 0.92,
                crunch: 0.08,
                splash: 0.45 + wetness * 0.45,
                squish: 0.55 + wetness * 0.35,
                lowResonance: 0.48,
                highSparkle: 0.12
            )
        case .snow:
            return AudioSurfaceResponse(
                materialKind: .snow,
                profileID: "surface.snow.compress",
                gainScale: 0.64 + friction * 0.10,
                pitchOffsetCents: -70,
                hardness: 0.20,
                roughness: 0.55,
                porosity: 0.78,
                crunch: 0.50 * (1 - wetness * 0.25),
                splash: wetness * 0.16,
                squish: wetness * 0.22,
                lowResonance: 0.18,
                highSparkle: 0.58
            )
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
