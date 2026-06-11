public struct CliffBandFeature: TerrainFeature, Equatable, Codable, Sendable {
    public let id: StableID
    public let centerX: Float
    public let centerZ: Float
    public let length: Float
    public let width: Float
    public let angleRadians: Float
    public let heightStep: Float

    public var kind: TerrainFeatureKind {
        .cliffBand
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
        heightStep: Float
    ) {
        precondition(length > 0, "Cliff band length must be positive.")
        precondition(width > 0, "Cliff band width must be positive.")
        self.id = id
        self.centerX = centerX
        self.centerZ = centerZ
        self.length = length
        self.width = width
        self.angleRadians = angleRadians
        self.heightStep = heightStep
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
        let edgeMask = 1 - TerrainFeatureMath.smoothStep(
            edge0: width * 0.35,
            edge1: width,
            abs(local.cross)
        )
        let cliffMask = alongMask * edgeMask
        let signedStep: Float = local.cross >= 0 ? heightStep : -heightStep * 0.35

        return TerrainFeatureContribution(
            heightOffset: signedStep * cliffMask,
            masks: TerrainFeatureMasks(cliff: cliffMask)
        )
    }
}
