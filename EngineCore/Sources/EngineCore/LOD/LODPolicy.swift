public struct LODPolicy: Equatable, Codable, Sendable {
    public struct DistanceThresholds: Equatable, Codable, Sendable {
        public let lod0MaxDistance: Float
        public let lod1MaxDistance: Float
        public let lod2MaxDistance: Float
        public let visibleMaxDistance: Float

        public init(
            lod0MaxDistance: Float,
            lod1MaxDistance: Float,
            lod2MaxDistance: Float,
            visibleMaxDistance: Float
        ) {
            precondition(lod0MaxDistance > 0, "lod0MaxDistance must be positive.")
            precondition(lod1MaxDistance >= lod0MaxDistance, "lod1MaxDistance must be >= lod0MaxDistance.")
            precondition(lod2MaxDistance >= lod1MaxDistance, "lod2MaxDistance must be >= lod1MaxDistance.")
            precondition(visibleMaxDistance >= lod2MaxDistance, "visibleMaxDistance must be >= lod2MaxDistance.")

            self.lod0MaxDistance = lod0MaxDistance
            self.lod1MaxDistance = lod1MaxDistance
            self.lod2MaxDistance = lod2MaxDistance
            self.visibleMaxDistance = visibleMaxDistance
        }
    }

    public let thresholds: DistanceThresholds
    public let hysteresis: Hysteresis
    public let budget: LODBudget
    public let chunkWorldExtent: Float
    public let viewportHeightPixels: Float

    public init(
        thresholds: DistanceThresholds,
        hysteresis: Hysteresis,
        budget: LODBudget,
        chunkWorldExtent: Float,
        viewportHeightPixels: Float
    ) {
        precondition(chunkWorldExtent > 0, "chunkWorldExtent must be positive.")

        self.thresholds = thresholds
        self.hysteresis = hysteresis
        self.budget = budget
        self.chunkWorldExtent = chunkWorldExtent
        self.viewportHeightPixels = max(viewportHeightPixels, 1)
    }

    public static func chunkBaseline(chunkWorldExtent: Float) -> LODPolicy {
        LODPolicy(
            thresholds: DistanceThresholds(
                lod0MaxDistance: chunkWorldExtent * 1.45,
                lod1MaxDistance: chunkWorldExtent * 2.35,
                lod2MaxDistance: chunkWorldExtent * 3.25,
                visibleMaxDistance: chunkWorldExtent * 3.75
            ),
            hysteresis: Hysteresis(distanceMargin: chunkWorldExtent * 0.15),
            budget: LODBudget(
                maxVisibleChunks: 13,
                maxTerrainDrawCalls: 13,
                maxPropDrawCalls: 9
            ),
            chunkWorldExtent: chunkWorldExtent,
            viewportHeightPixels: 900
        )
    }

    func rawLevel(forDistance distance: Float) -> LODLevel {
        if distance <= thresholds.lod0MaxDistance {
            return .lod0
        }

        if distance <= thresholds.lod1MaxDistance {
            return .lod1
        }

        if distance <= thresholds.lod2MaxDistance {
            return .lod2
        }

        return .lod3
    }
}
