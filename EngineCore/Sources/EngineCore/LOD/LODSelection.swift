public enum LODCullingReason: String, Codable, Sendable {
    case visible
    case distance
    case budget
}

public struct LODSelection: Equatable, Codable, Sendable {
    public let level: LODLevel
    public let distance: Float
    public let screenError: ScreenError
    public let isVisible: Bool
    public let cullingReason: LODCullingReason
    public let rendersProps: Bool

    public init(
        level: LODLevel,
        distance: Float,
        screenError: ScreenError,
        isVisible: Bool,
        cullingReason: LODCullingReason,
        rendersProps: Bool? = nil
    ) {
        self.level = level
        self.distance = max(distance, 0)
        self.screenError = screenError
        self.isVisible = isVisible
        self.cullingReason = cullingReason
        self.rendersProps = isVisible && (rendersProps ?? level.rendersProps)
    }

    public static func select(
        distance: Float,
        fieldOfViewDegrees: Float,
        policy: LODPolicy,
        previousLevel: LODLevel? = nil
    ) -> LODSelection {
        let screenError = ScreenError.estimateProjectedPixels(
            worldExtent: policy.chunkWorldExtent,
            distance: max(distance, 0.001),
            fieldOfViewDegrees: fieldOfViewDegrees,
            viewportHeightPixels: policy.viewportHeightPixels
        )
        let rawLevel = policy.rawLevel(forDistance: distance)
        let level = policy.hysteresis.stabilizedLevel(
            rawLevel: rawLevel,
            previousLevel: previousLevel,
            distance: distance,
            thresholds: policy.thresholds
        )
        let isWithinDistance = distance <= policy.thresholds.visibleMaxDistance

        return LODSelection(
            level: level,
            distance: distance,
            screenError: screenError,
            isVisible: isWithinDistance,
            cullingReason: isWithinDistance ? .visible : .distance
        )
    }

    public func culledByBudget() -> LODSelection {
        LODSelection(
            level: level,
            distance: distance,
            screenError: screenError,
            isVisible: false,
            cullingReason: .budget
        )
    }

    public func withoutProps() -> LODSelection {
        LODSelection(
            level: level,
            distance: distance,
            screenError: screenError,
            isVisible: isVisible,
            cullingReason: cullingReason,
            rendersProps: false
        )
    }

    public static let visibleLOD0 = LODSelection(
        level: .lod0,
        distance: 0,
        screenError: ScreenError(projectedPixels: 0),
        isVisible: true,
        cullingReason: .visible
    )
}

public struct LODFrameStats: Equatable, Codable, Sendable {
    public static let empty = LODFrameStats()

    public let candidateChunkCount: Int
    public let visibleChunkCount: Int
    public let culledChunkCount: Int
    public let lod0ChunkCount: Int
    public let lod1ChunkCount: Int
    public let lod2ChunkCount: Int
    public let lod3ChunkCount: Int

    public init(
        candidateChunkCount: Int = 0,
        visibleChunkCount: Int = 0,
        culledChunkCount: Int = 0,
        lod0ChunkCount: Int = 0,
        lod1ChunkCount: Int = 0,
        lod2ChunkCount: Int = 0,
        lod3ChunkCount: Int = 0
    ) {
        self.candidateChunkCount = max(candidateChunkCount, 0)
        self.visibleChunkCount = max(visibleChunkCount, 0)
        self.culledChunkCount = max(culledChunkCount, 0)
        self.lod0ChunkCount = max(lod0ChunkCount, 0)
        self.lod1ChunkCount = max(lod1ChunkCount, 0)
        self.lod2ChunkCount = max(lod2ChunkCount, 0)
        self.lod3ChunkCount = max(lod3ChunkCount, 0)
    }

    public init(selections: [LODSelection]) {
        var visibleCount = 0
        var culledCount = 0
        var lod0Count = 0
        var lod1Count = 0
        var lod2Count = 0
        var lod3Count = 0

        for selection in selections {
            if selection.isVisible {
                visibleCount += 1

                switch selection.level {
                case .lod0:
                    lod0Count += 1
                case .lod1:
                    lod1Count += 1
                case .lod2:
                    lod2Count += 1
                case .lod3:
                    lod3Count += 1
                }
            } else {
                culledCount += 1
            }
        }

        self.init(
            candidateChunkCount: selections.count,
            visibleChunkCount: visibleCount,
            culledChunkCount: culledCount,
            lod0ChunkCount: lod0Count,
            lod1ChunkCount: lod1Count,
            lod2ChunkCount: lod2Count,
            lod3ChunkCount: lod3Count
        )
    }
}
