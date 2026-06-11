import Foundation

public enum TraversalSurfaceClass: String, CaseIterable, Codable, Sendable {
    case walkable
    case steep
    case climbable
    case dangerous
    case blocked

    public static func classify(_ sample: TerrainSample) -> TraversalSurfaceClass {
        let slopeDegrees = slopeDegrees(for: sample.slope)

        if sample.waterDepth >= 0.35 || sample.featureMasks.water >= 0.72 {
            return .blocked
        }

        if slopeDegrees >= 78 || (sample.walkability <= 0.10 && sample.climbability <= 0.12) {
            return .dangerous
        }

        if sample.climbability >= 0.46 ||
            sample.featureMasks.cliff >= 0.34 ||
            (slopeDegrees >= 45 && slopeDegrees < 78) {
            return .climbable
        }

        if sample.walkability >= 0.55 && slopeDegrees <= 34 && sample.waterDepth < 0.12 {
            return .walkable
        }

        return .steep
    }

    public var isWalkableForPlayer: Bool {
        self == .walkable
    }

    public var supportsVerticalTraversal: Bool {
        switch self {
        case .steep, .climbable:
            return true
        case .walkable, .dangerous, .blocked:
            return false
        }
    }

    public var isBlockedForFootTraversal: Bool {
        switch self {
        case .dangerous, .blocked:
            return true
        case .walkable, .steep, .climbable:
            return false
        }
    }

    public var debugValue: Float {
        switch self {
        case .walkable:
            return 0.18
        case .steep:
            return 0.38
        case .climbable:
            return 0.58
        case .dangerous:
            return 0.78
        case .blocked:
            return 1.0
        }
    }

    public static func slopeDegrees(for slope: Float) -> Float {
        Float(atan(Double(max(slope, 0)))) * 180 / Float.pi
    }
}
