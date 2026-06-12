public struct FXDefinitionID: RawRepresentable, Equatable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        precondition(!rawValue.isEmpty, "FXDefinitionID cannot be empty.")
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.init(rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public enum FXDefinitionKind: String, CaseIterable, Codable, Sendable {
    case billboardSprite
    case decal
}

public enum FXBlendMode: String, CaseIterable, Codable, Sendable {
    case opaque
    case alpha
    case additive
}

public struct FXColor: Equatable, Hashable, Codable, Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
        self.red = Self.clamped01(red)
        self.green = Self.clamped01(green)
        self.blue = Self.clamped01(blue)
        self.alpha = Self.clamped01(alpha)
    }

    public func withAlpha(_ alpha: Float) -> FXColor {
        FXColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public func mixed(with other: FXColor, amount: Float) -> FXColor {
        let t = Self.clamped01(amount)
        return FXColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }

    public func tinted(by tint: FXColor) -> FXColor {
        FXColor(
            red: red * tint.red,
            green: green * tint.green,
            blue: blue * tint.blue,
            alpha: alpha * tint.alpha
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct FXFloatRange: Equatable, Hashable, Codable, Sendable {
    public let lowerBound: Float
    public let upperBound: Float

    public init(_ lowerBound: Float, _ upperBound: Float) {
        self.lowerBound = min(lowerBound, upperBound)
        self.upperBound = max(lowerBound, upperBound)
    }

    public func sample(_ unitValue: Float) -> Float {
        lowerBound + (upperBound - lowerBound) * min(max(unitValue, 0), 1)
    }
}

public struct FXIntRange: Equatable, Hashable, Codable, Sendable {
    public let lowerBound: Int
    public let upperBound: Int

    public init(_ lowerBound: Int, _ upperBound: Int) {
        self.lowerBound = min(lowerBound, upperBound)
        self.upperBound = max(lowerBound, upperBound)
    }

    public func sample(_ unitValue: Float) -> Int {
        guard lowerBound != upperBound else {
            return lowerBound
        }

        let clamped = min(max(unitValue, 0), 0.999_999)
        let span = upperBound - lowerBound + 1
        return lowerBound + min(Int(Float(span) * clamped), span - 1)
    }
}

public struct FXScalarCurvePoint: Equatable, Hashable, Codable, Sendable {
    public let progress: Float
    public let value: Float

    public init(progress: Float, value: Float) {
        self.progress = min(max(progress, 0), 1)
        self.value = value
    }
}

public struct FXScalarCurve: Equatable, Hashable, Codable, Sendable {
    public let points: [FXScalarCurvePoint]

    public init(points: [FXScalarCurvePoint]) {
        precondition(!points.isEmpty, "FXScalarCurve requires at least one point.")
        self.points = points.sorted { $0.progress < $1.progress }
    }

    public static let constantOne = FXScalarCurve(points: [
        FXScalarCurvePoint(progress: 0, value: 1),
        FXScalarCurvePoint(progress: 1, value: 1),
    ])

    public func sample(progress: Float) -> Float {
        let t = min(max(progress, 0), 1)

        guard points.count > 1 else {
            return points[0].value
        }

        if t <= points[0].progress {
            return points[0].value
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]

            if t <= current.progress {
                let segment = max(current.progress - previous.progress, 0.000_001)
                let localT = (t - previous.progress) / segment
                return previous.value + (current.value - previous.value) * localT
            }
        }

        return points[points.count - 1].value
    }
}

public struct FXColorCurvePoint: Equatable, Hashable, Codable, Sendable {
    public let progress: Float
    public let color: FXColor

    public init(progress: Float, color: FXColor) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
    }
}

public struct FXColorCurve: Equatable, Hashable, Codable, Sendable {
    public let points: [FXColorCurvePoint]

    public init(points: [FXColorCurvePoint]) {
        precondition(!points.isEmpty, "FXColorCurve requires at least one point.")
        self.points = points.sorted { $0.progress < $1.progress }
    }

    public static let opaqueWhite = FXColorCurve(points: [
        FXColorCurvePoint(progress: 0, color: FXColor(red: 1, green: 1, blue: 1, alpha: 1)),
        FXColorCurvePoint(progress: 1, color: FXColor(red: 1, green: 1, blue: 1, alpha: 1)),
    ])

    public func sample(progress: Float) -> FXColor {
        let t = min(max(progress, 0), 1)

        guard points.count > 1 else {
            return points[0].color
        }

        if t <= points[0].progress {
            return points[0].color
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]

            if t <= current.progress {
                let segment = max(current.progress - previous.progress, 0.000_001)
                let localT = (t - previous.progress) / segment
                return previous.color.mixed(with: current.color, amount: localT)
            }
        }

        return points[points.count - 1].color
    }
}

public struct FXDefinition: Equatable, Hashable, Codable, Sendable {
    public let id: FXDefinitionID
    public let kind: FXDefinitionKind
    public let blendMode: FXBlendMode
    public let burstCount: FXIntRange
    public let lifetimeSeconds: FXFloatRange
    public let startSize: FXFloatRange
    public let initialSpeed: FXFloatRange
    public let upwardVelocity: FXFloatRange
    public let gravity: Float
    public let colorOverLife: FXColorCurve
    public let sizeOverLife: FXScalarCurve

    public init(
        id: FXDefinitionID,
        kind: FXDefinitionKind,
        blendMode: FXBlendMode,
        burstCount: FXIntRange,
        lifetimeSeconds: FXFloatRange,
        startSize: FXFloatRange,
        initialSpeed: FXFloatRange,
        upwardVelocity: FXFloatRange,
        gravity: Float,
        colorOverLife: FXColorCurve,
        sizeOverLife: FXScalarCurve
    ) {
        self.id = id
        self.kind = kind
        self.blendMode = blendMode
        self.burstCount = burstCount
        self.lifetimeSeconds = lifetimeSeconds
        self.startSize = startSize
        self.initialSpeed = initialSpeed
        self.upwardVelocity = upwardVelocity
        self.gravity = gravity
        self.colorOverLife = colorOverLife
        self.sizeOverLife = sizeOverLife
    }
}

public extension FXDefinitionID {
    static let footstepDust: FXDefinitionID = "fx.footstep.dust"
    static let footstepSplash: FXDefinitionID = "fx.footstep.splash"
    static let impactSparks: FXDefinitionID = "fx.impact.sparks"
    static let footprintDecal: FXDefinitionID = "fx.footstep.decal"
}

public extension FXDefinition {
    static let footstepDust = FXDefinition(
        id: .footstepDust,
        kind: .billboardSprite,
        blendMode: .alpha,
        burstCount: FXIntRange(4, 8),
        lifetimeSeconds: FXFloatRange(0.32, 0.58),
        startSize: FXFloatRange(0.10, 0.22),
        initialSpeed: FXFloatRange(0.18, 0.48),
        upwardVelocity: FXFloatRange(0.10, 0.26),
        gravity: -0.08,
        colorOverLife: FXColorCurve(points: [
            FXColorCurvePoint(progress: 0, color: FXColor(red: 1, green: 1, blue: 1, alpha: 0.55)),
            FXColorCurvePoint(progress: 1, color: FXColor(red: 1, green: 1, blue: 1, alpha: 0)),
        ]),
        sizeOverLife: FXScalarCurve(points: [
            FXScalarCurvePoint(progress: 0, value: 0.65),
            FXScalarCurvePoint(progress: 1, value: 1.35),
        ])
    )

    static let footstepSplash = FXDefinition(
        id: .footstepSplash,
        kind: .billboardSprite,
        blendMode: .alpha,
        burstCount: FXIntRange(5, 10),
        lifetimeSeconds: FXFloatRange(0.26, 0.48),
        startSize: FXFloatRange(0.08, 0.18),
        initialSpeed: FXFloatRange(0.26, 0.62),
        upwardVelocity: FXFloatRange(0.18, 0.46),
        gravity: -0.42,
        colorOverLife: FXColorCurve(points: [
            FXColorCurvePoint(progress: 0, color: FXColor(red: 0.78, green: 0.92, blue: 1, alpha: 0.70)),
            FXColorCurvePoint(progress: 1, color: FXColor(red: 0.78, green: 0.92, blue: 1, alpha: 0)),
        ]),
        sizeOverLife: FXScalarCurve(points: [
            FXScalarCurvePoint(progress: 0, value: 0.55),
            FXScalarCurvePoint(progress: 0.45, value: 1.10),
            FXScalarCurvePoint(progress: 1, value: 0.40),
        ])
    )

    static let impactSparks = FXDefinition(
        id: .impactSparks,
        kind: .billboardSprite,
        blendMode: .additive,
        burstCount: FXIntRange(3, 7),
        lifetimeSeconds: FXFloatRange(0.14, 0.28),
        startSize: FXFloatRange(0.04, 0.09),
        initialSpeed: FXFloatRange(0.40, 0.95),
        upwardVelocity: FXFloatRange(0.16, 0.38),
        gravity: -0.65,
        colorOverLife: FXColorCurve(points: [
            FXColorCurvePoint(progress: 0, color: FXColor(red: 1, green: 0.82, blue: 0.22, alpha: 0.95)),
            FXColorCurvePoint(progress: 1, color: FXColor(red: 1, green: 0.28, blue: 0.08, alpha: 0)),
        ]),
        sizeOverLife: FXScalarCurve(points: [
            FXScalarCurvePoint(progress: 0, value: 1),
            FXScalarCurvePoint(progress: 1, value: 0.15),
        ])
    )

    static let footprintDecal = FXDefinition(
        id: .footprintDecal,
        kind: .decal,
        blendMode: .alpha,
        burstCount: FXIntRange(1, 1),
        lifetimeSeconds: FXFloatRange(2.0, 3.6),
        startSize: FXFloatRange(0.28, 0.42),
        initialSpeed: FXFloatRange(0, 0),
        upwardVelocity: FXFloatRange(0, 0),
        gravity: 0,
        colorOverLife: FXColorCurve(points: [
            FXColorCurvePoint(progress: 0, color: FXColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 0.42)),
            FXColorCurvePoint(progress: 1, color: FXColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 0)),
        ]),
        sizeOverLife: .constantOne
    )

    static let v1Definitions: [FXDefinition] = [
        .footstepDust,
        .footstepSplash,
        .impactSparks,
        .footprintDecal,
    ]
}
