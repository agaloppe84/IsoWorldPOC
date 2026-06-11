public struct RiverFeature: TerrainFeature, Equatable, Codable, Sendable {
    public let id: StableID
    public let startX: Float
    public let startZ: Float
    public let endX: Float
    public let endZ: Float
    public let width: Float
    public let shoreWidth: Float
    public let carveDepth: Float
    public let waterDepth: Float

    public var kind: TerrainFeatureKind {
        .river
    }

    public var bounds: TerrainFeatureBounds {
        TerrainFeatureBounds(
            minX: min(startX, endX),
            maxX: max(startX, endX),
            minZ: min(startZ, endZ),
            maxZ: max(startZ, endZ)
        )
        .expanded(by: width + shoreWidth * 2)
    }

    public init(
        id: StableID,
        startX: Float,
        startZ: Float,
        endX: Float,
        endZ: Float,
        width: Float,
        shoreWidth: Float,
        carveDepth: Float,
        waterDepth: Float
    ) {
        precondition(width > 0, "River width must be positive.")
        precondition(shoreWidth >= 0, "River shore width cannot be negative.")
        self.id = id
        self.startX = startX
        self.startZ = startZ
        self.endX = endX
        self.endZ = endZ
        self.width = width
        self.shoreWidth = shoreWidth
        self.carveDepth = max(carveDepth, 0)
        self.waterDepth = max(waterDepth, 0)
    }

    public func contribution(at point: TerrainFeaturePoint) -> TerrainFeatureContribution {
        guard bounds.contains(point) else {
            return .zero
        }

        let distance = TerrainFeatureMath.distance(
            from: point,
            toSegmentStart: (startX, startZ),
            end: (endX, endZ)
        )
        let channelMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: width * 0.45,
            edge1: width,
            distance
        )
        let valleyMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: width,
            edge1: width + shoreWidth * 2,
            distance
        )
        let shoreMask = TerrainFeatureMath.smoothStep(
            edge0: width * 0.55,
            edge1: width,
            distance
        ) * (1 - TerrainFeatureMath.smoothStep(
            edge0: width,
            edge1: width + shoreWidth,
            distance
        ))
        let heightOffset = -(carveDepth * channelMask + carveDepth * 0.30 * valleyMask)

        return TerrainFeatureContribution(
            heightOffset: heightOffset,
            waterDepth: waterDepth * channelMask,
            masks: TerrainFeatureMasks(
                water: channelMask,
                shore: shoreMask
            )
        )
    }
}
