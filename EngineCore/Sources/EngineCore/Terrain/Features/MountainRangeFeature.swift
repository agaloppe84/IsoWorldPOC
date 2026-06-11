public struct MountainRangeFeature: TerrainFeature, Equatable, Codable, Sendable {
    public let id: StableID
    public let centerX: Float
    public let centerZ: Float
    public let length: Float
    public let width: Float
    public let angleRadians: Float
    public let amplitude: Float

    public var kind: TerrainFeatureKind {
        .mountainRange
    }

    public var bounds: TerrainFeatureBounds {
        let extent = length * 0.5 + width * 2

        return TerrainFeatureBounds(
            minX: centerX - extent,
            maxX: centerX + extent,
            minZ: centerZ - extent,
            maxZ: centerZ + extent
        )
    }

    public init(
        id: StableID,
        centerX: Float,
        centerZ: Float,
        length: Float,
        width: Float,
        angleRadians: Float,
        amplitude: Float
    ) {
        precondition(length > 0, "Mountain range length must be positive.")
        precondition(width > 0, "Mountain range width must be positive.")
        self.id = id
        self.centerX = centerX
        self.centerZ = centerZ
        self.length = length
        self.width = width
        self.angleRadians = angleRadians
        self.amplitude = max(amplitude, 0)
    }

    public func contribution(at point: TerrainFeaturePoint) -> TerrainFeatureContribution {
        guard bounds.contains(point) else {
            return .zero
        }

        let local = TerrainFeatureMath.orientedLocal(
            point: point,
            centerX: centerX,
            centerZ: centerZ,
            angleRadians: angleRadians
        )
        let alongMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: length * 0.42,
            edge1: length * 0.5,
            abs(local.along)
        )
        let ridgeMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: width * 0.12,
            edge1: width,
            abs(local.cross)
        )
        let foothillMask = (1 - TerrainFeatureMath.smoothStep(
            edge0: width,
            edge1: width * 2,
            abs(local.cross)
        )) * 0.32
        let mountainMask = max(ridgeMask, foothillMask) * alongMask
        let heightOffset = amplitude * (ridgeMask + foothillMask) * alongMask

        return TerrainFeatureContribution(
            heightOffset: heightOffset,
            masks: TerrainFeatureMasks(mountain: mountainMask)
        )
    }
}
