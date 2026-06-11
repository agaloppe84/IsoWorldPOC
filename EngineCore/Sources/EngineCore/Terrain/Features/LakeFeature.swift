public struct LakeFeature: TerrainFeature, Equatable, Codable, Sendable {
    public let id: StableID
    public let centerX: Float
    public let centerZ: Float
    public let radius: Float
    public let shoreWidth: Float
    public let basinDepth: Float
    public let waterDepth: Float

    public var kind: TerrainFeatureKind {
        .lake
    }

    public var bounds: TerrainFeatureBounds {
        TerrainFeatureBounds(
            minX: centerX - radius,
            maxX: centerX + radius,
            minZ: centerZ - radius,
            maxZ: centerZ + radius
        )
        .expanded(by: shoreWidth)
    }

    public init(
        id: StableID,
        centerX: Float,
        centerZ: Float,
        radius: Float,
        shoreWidth: Float,
        basinDepth: Float,
        waterDepth: Float
    ) {
        precondition(radius > 0, "Lake radius must be positive.")
        precondition(shoreWidth >= 0, "Lake shore width cannot be negative.")
        self.id = id
        self.centerX = centerX
        self.centerZ = centerZ
        self.radius = radius
        self.shoreWidth = shoreWidth
        self.basinDepth = max(basinDepth, 0)
        self.waterDepth = max(waterDepth, 0)
    }

    public func contribution(at point: TerrainFeaturePoint) -> TerrainFeatureContribution {
        guard bounds.contains(point) else {
            return .zero
        }

        let dx = point.worldX - centerX
        let dz = point.worldZ - centerZ
        let distance = (dx * dx + dz * dz).squareRoot()
        let waterMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: radius * 0.72,
            edge1: radius,
            distance
        )
        let basinMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: radius * 0.55,
            edge1: radius + shoreWidth,
            distance
        )
        let shoreMask = TerrainFeatureMath.smoothStep(
            edge0: radius * 0.72,
            edge1: radius,
            distance
        ) * (1 - TerrainFeatureMath.smoothStep(
            edge0: radius,
            edge1: radius + shoreWidth,
            distance
        ))

        return TerrainFeatureContribution(
            heightOffset: -basinDepth * basinMask,
            waterDepth: waterDepth * waterMask,
            masks: TerrainFeatureMasks(
                water: waterMask,
                shore: shoreMask
            )
        )
    }
}
