public struct Hysteresis: Equatable, Codable, Sendable {
    public let distanceMargin: Float

    public init(distanceMargin: Float) {
        self.distanceMargin = max(distanceMargin, 0)
    }

    func stabilizedLevel(
        rawLevel: LODLevel,
        previousLevel: LODLevel?,
        distance: Float,
        thresholds: LODPolicy.DistanceThresholds
    ) -> LODLevel {
        guard let previousLevel, previousLevel != rawLevel, distanceMargin > 0 else {
            return rawLevel
        }

        switch (previousLevel, rawLevel) {
        case (.lod0, .lod1) where distance <= thresholds.lod0MaxDistance + distanceMargin:
            return .lod0
        case (.lod1, .lod0) where distance >= thresholds.lod0MaxDistance - distanceMargin:
            return .lod1
        case (.lod1, .lod2) where distance <= thresholds.lod1MaxDistance + distanceMargin:
            return .lod1
        case (.lod2, .lod1) where distance >= thresholds.lod1MaxDistance - distanceMargin:
            return .lod2
        case (.lod2, .lod3) where distance <= thresholds.lod2MaxDistance + distanceMargin:
            return .lod2
        case (.lod3, .lod2) where distance >= thresholds.lod2MaxDistance - distanceMargin:
            return .lod3
        default:
            return rawLevel
        }
    }
}
