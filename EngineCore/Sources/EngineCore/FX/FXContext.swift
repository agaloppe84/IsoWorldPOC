public struct FXContext: Equatable, Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let simulationTime: Float
    public let cameraPosition: WorldPosition?

    public init(
        worldSeed: WorldSeed,
        simulationTime: Float,
        cameraPosition: WorldPosition? = nil
    ) {
        self.worldSeed = worldSeed
        self.simulationTime = max(simulationTime, 0)
        self.cameraPosition = cameraPosition
    }

    public func surfaceResponse(
        for materialKind: TerrainMaterialKind,
        wetness: Float,
        friction: Float
    ) -> FXSurfaceResponse {
        FXSurfaceResponse.response(
            for: materialKind,
            wetness: wetness,
            friction: friction
        )
    }
}

public struct FXSurfaceResponse: Equatable, Hashable, Codable, Sendable {
    public let materialKind: TerrainMaterialKind
    public let dustColor: FXColor
    public let splashColor: FXColor
    public let sparkColor: FXColor
    public let decalColor: FXColor
    public let dustMultiplier: Float
    public let splashMultiplier: Float
    public let wetnessSplashMultiplier: Float
    public let impactSparkChance: Float
    public let footprintDecalStrength: Float
    public let debrisSizeScale: Float
    public let friction: Float
    public let restitution: Float
    public let adhesion: Float
    public let soundProfile: String
    public let particlePalette: [FXColor]

    public init(
        materialKind: TerrainMaterialKind,
        dustColor: FXColor,
        splashColor: FXColor,
        sparkColor: FXColor,
        decalColor: FXColor,
        dustMultiplier: Float,
        splashMultiplier: Float,
        wetnessSplashMultiplier: Float,
        impactSparkChance: Float,
        footprintDecalStrength: Float,
        debrisSizeScale: Float,
        friction: Float,
        restitution: Float,
        adhesion: Float,
        soundProfile: String,
        particlePalette: [FXColor]
    ) {
        self.materialKind = materialKind
        self.dustColor = dustColor
        self.splashColor = splashColor
        self.sparkColor = sparkColor
        self.decalColor = decalColor
        self.dustMultiplier = max(dustMultiplier, 0)
        self.splashMultiplier = max(splashMultiplier, 0)
        self.wetnessSplashMultiplier = max(wetnessSplashMultiplier, 0)
        self.impactSparkChance = Self.clamped01(impactSparkChance)
        self.footprintDecalStrength = Self.clamped01(footprintDecalStrength)
        self.debrisSizeScale = max(debrisSizeScale, 0.01)
        self.friction = Self.clamped01(friction)
        self.restitution = Self.clamped01(restitution)
        self.adhesion = Self.clamped01(adhesion)
        self.soundProfile = soundProfile
        self.particlePalette = particlePalette
    }

    public static func response(
        for materialKind: TerrainMaterialKind,
        wetness: Float,
        friction: Float
    ) -> FXSurfaceResponse {
        let wetness = clamped01(wetness)
        let friction = clamped01(friction)

        switch materialKind {
        case .grass:
            return FXSurfaceResponse(
                materialKind: materialKind,
                dustColor: FXColor(red: 0.40, green: 0.55, blue: 0.28, alpha: 0.68),
                splashColor: FXColor(red: 0.52, green: 0.72, blue: 0.62, alpha: 0.72),
                sparkColor: FXColor(red: 0.76, green: 0.90, blue: 0.30, alpha: 0.70),
                decalColor: FXColor(red: 0.14, green: 0.22, blue: 0.08, alpha: 0.32),
                dustMultiplier: 0.75 * (1 - wetness * 0.65),
                splashMultiplier: wetness,
                wetnessSplashMultiplier: 1.15,
                impactSparkChance: 0.02,
                footprintDecalStrength: 0.35 + wetness * 0.20,
                debrisSizeScale: 0.75,
                friction: friction,
                restitution: 0.08,
                adhesion: 0.20 + wetness * 0.25,
                soundProfile: "surface.grass",
                particlePalette: [
                    FXColor(red: 0.32, green: 0.48, blue: 0.22, alpha: 0.65),
                    FXColor(red: 0.52, green: 0.58, blue: 0.32, alpha: 0.55),
                ]
            )
        case .rock:
            return FXSurfaceResponse(
                materialKind: materialKind,
                dustColor: FXColor(red: 0.45, green: 0.44, blue: 0.39, alpha: 0.72),
                splashColor: FXColor(red: 0.62, green: 0.70, blue: 0.74, alpha: 0.70),
                sparkColor: FXColor(red: 1.00, green: 0.76, blue: 0.18, alpha: 0.92),
                decalColor: FXColor(red: 0.10, green: 0.10, blue: 0.09, alpha: 0.26),
                dustMultiplier: 1.10 * (1 - wetness * 0.45),
                splashMultiplier: wetness * 0.35,
                wetnessSplashMultiplier: 0.50,
                impactSparkChance: 0.45,
                footprintDecalStrength: 0.22,
                debrisSizeScale: 0.95,
                friction: friction,
                restitution: 0.35,
                adhesion: 0.04,
                soundProfile: "surface.rock",
                particlePalette: [
                    FXColor(red: 0.40, green: 0.39, blue: 0.35, alpha: 0.66),
                    FXColor(red: 0.62, green: 0.58, blue: 0.48, alpha: 0.55),
                ]
            )
        case .dirt:
            return FXSurfaceResponse(
                materialKind: materialKind,
                dustColor: FXColor(red: 0.46, green: 0.32, blue: 0.18, alpha: 0.74),
                splashColor: FXColor(red: 0.34, green: 0.28, blue: 0.22, alpha: 0.74),
                sparkColor: FXColor(red: 0.84, green: 0.58, blue: 0.20, alpha: 0.70),
                decalColor: FXColor(red: 0.18, green: 0.11, blue: 0.06, alpha: 0.36),
                dustMultiplier: 1.00 * (1 - wetness * 0.70),
                splashMultiplier: wetness * 0.75,
                wetnessSplashMultiplier: 0.95,
                impactSparkChance: 0.05,
                footprintDecalStrength: 0.42 + wetness * 0.25,
                debrisSizeScale: 0.85,
                friction: friction,
                restitution: 0.10,
                adhesion: 0.18 + wetness * 0.34,
                soundProfile: "surface.dirt",
                particlePalette: [
                    FXColor(red: 0.40, green: 0.26, blue: 0.14, alpha: 0.65),
                    FXColor(red: 0.54, green: 0.39, blue: 0.23, alpha: 0.56),
                ]
            )
        case .sand:
            return FXSurfaceResponse(
                materialKind: materialKind,
                dustColor: FXColor(red: 0.76, green: 0.66, blue: 0.40, alpha: 0.78),
                splashColor: FXColor(red: 0.62, green: 0.64, blue: 0.56, alpha: 0.64),
                sparkColor: FXColor(red: 0.92, green: 0.72, blue: 0.28, alpha: 0.62),
                decalColor: FXColor(red: 0.38, green: 0.30, blue: 0.16, alpha: 0.28),
                dustMultiplier: 1.30 * (1 - wetness * 0.58),
                splashMultiplier: wetness * 0.45,
                wetnessSplashMultiplier: 0.60,
                impactSparkChance: 0.03,
                footprintDecalStrength: 0.52,
                debrisSizeScale: 0.65,
                friction: friction,
                restitution: 0.06,
                adhesion: 0.10 + wetness * 0.18,
                soundProfile: "surface.sand",
                particlePalette: [
                    FXColor(red: 0.68, green: 0.58, blue: 0.34, alpha: 0.68),
                    FXColor(red: 0.88, green: 0.78, blue: 0.52, alpha: 0.58),
                ]
            )
        case .mud:
            return FXSurfaceResponse(
                materialKind: materialKind,
                dustColor: FXColor(red: 0.20, green: 0.28, blue: 0.20, alpha: 0.55),
                splashColor: FXColor(red: 0.17, green: 0.34, blue: 0.27, alpha: 0.82),
                sparkColor: FXColor(red: 0.58, green: 0.48, blue: 0.24, alpha: 0.42),
                decalColor: FXColor(red: 0.08, green: 0.14, blue: 0.10, alpha: 0.50),
                dustMultiplier: 0.20 * (1 - wetness),
                splashMultiplier: 0.85 + wetness * 0.50,
                wetnessSplashMultiplier: 1.55,
                impactSparkChance: 0.01,
                footprintDecalStrength: 0.70,
                debrisSizeScale: 0.80,
                friction: friction,
                restitution: 0.04,
                adhesion: 0.55 + wetness * 0.30,
                soundProfile: "surface.mud",
                particlePalette: [
                    FXColor(red: 0.14, green: 0.28, blue: 0.22, alpha: 0.70),
                    FXColor(red: 0.24, green: 0.36, blue: 0.26, alpha: 0.58),
                ]
            )
        case .snow:
            return FXSurfaceResponse(
                materialKind: materialKind,
                dustColor: FXColor(red: 0.86, green: 0.94, blue: 0.94, alpha: 0.72),
                splashColor: FXColor(red: 0.74, green: 0.90, blue: 1.00, alpha: 0.62),
                sparkColor: FXColor(red: 0.82, green: 0.92, blue: 1.00, alpha: 0.52),
                decalColor: FXColor(red: 0.56, green: 0.66, blue: 0.66, alpha: 0.30),
                dustMultiplier: 0.90,
                splashMultiplier: wetness * 0.25,
                wetnessSplashMultiplier: 0.45,
                impactSparkChance: 0.01,
                footprintDecalStrength: 0.60,
                debrisSizeScale: 0.70,
                friction: friction,
                restitution: 0.12,
                adhesion: 0.20 + wetness * 0.10,
                soundProfile: "surface.snow",
                particlePalette: [
                    FXColor(red: 0.82, green: 0.92, blue: 0.92, alpha: 0.64),
                    FXColor(red: 0.94, green: 0.98, blue: 1.00, alpha: 0.55),
                ]
            )
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
