import Foundation

public enum TerrainFeatureKind: String, Codable, Sendable {
    case river
    case lake
    case mountainRange
    case cliffBand
}

public struct TerrainFeaturePoint: Equatable, Codable, Sendable {
    public let worldX: Float
    public let worldZ: Float
    public let baseHeight: Float

    public init(worldX: Float, worldZ: Float, baseHeight: Float = 0) {
        self.worldX = worldX
        self.worldZ = worldZ
        self.baseHeight = baseHeight
    }
}

public struct TerrainFeatureBounds: Equatable, Codable, Sendable {
    public let minX: Float
    public let maxX: Float
    public let minZ: Float
    public let maxZ: Float

    public init(minX: Float, maxX: Float, minZ: Float, maxZ: Float) {
        self.minX = min(minX, maxX)
        self.maxX = max(minX, maxX)
        self.minZ = min(minZ, maxZ)
        self.maxZ = max(minZ, maxZ)
    }

    public static func chunk(
        _ coordinate: ChunkCoordinate,
        gridStride: Int = ChunkHeightmap.gridStride
    ) -> TerrainFeatureBounds {
        let minX = Float(coordinate.x * gridStride)
        let minZ = Float(coordinate.z * gridStride)
        let maxX = minX + Float(gridStride)
        let maxZ = minZ + Float(gridStride)

        return TerrainFeatureBounds(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ)
    }

    public func expanded(by radius: Float) -> TerrainFeatureBounds {
        TerrainFeatureBounds(
            minX: minX - radius,
            maxX: maxX + radius,
            minZ: minZ - radius,
            maxZ: maxZ + radius
        )
    }

    public func contains(_ point: TerrainFeaturePoint) -> Bool {
        point.worldX >= minX &&
            point.worldX <= maxX &&
            point.worldZ >= minZ &&
            point.worldZ <= maxZ
    }

    public func intersects(_ other: TerrainFeatureBounds) -> Bool {
        minX <= other.maxX &&
            maxX >= other.minX &&
            minZ <= other.maxZ &&
            maxZ >= other.minZ
    }
}

public struct TerrainFeatureMasks: Equatable, Hashable, Codable, Sendable {
    public static let zero = TerrainFeatureMasks()

    public let water: Float
    public let shore: Float
    public let mountain: Float
    public let cliff: Float

    public init(
        water: Float = 0,
        shore: Float = 0,
        mountain: Float = 0,
        cliff: Float = 0
    ) {
        self.water = TerrainFeatureMath.clamped01(water)
        self.shore = TerrainFeatureMath.clamped01(shore)
        self.mountain = TerrainFeatureMath.clamped01(mountain)
        self.cliff = TerrainFeatureMath.clamped01(cliff)
    }

    public var maxValue: Float {
        max(max(water, shore), max(mountain, cliff))
    }
}

public struct TerrainFeatureContribution: Equatable, Codable, Sendable {
    public static let zero = TerrainFeatureContribution()

    public let heightOffset: Float
    public let waterDepth: Float
    public let masks: TerrainFeatureMasks

    public init(
        heightOffset: Float = 0,
        waterDepth: Float = 0,
        masks: TerrainFeatureMasks = .zero
    ) {
        self.heightOffset = heightOffset
        self.waterDepth = max(waterDepth, 0)
        self.masks = masks
    }

    public func merged(with other: TerrainFeatureContribution) -> TerrainFeatureContribution {
        TerrainFeatureContribution(
            heightOffset: heightOffset + other.heightOffset,
            waterDepth: max(waterDepth, other.waterDepth),
            masks: TerrainFeatureMasks(
                water: max(masks.water, other.masks.water),
                shore: max(masks.shore, other.masks.shore),
                mountain: max(masks.mountain, other.masks.mountain),
                cliff: max(masks.cliff, other.masks.cliff)
            )
        )
    }
}

public protocol TerrainFeature: Sendable {
    var id: StableID { get }
    var kind: TerrainFeatureKind { get }
    var bounds: TerrainFeatureBounds { get }

    func contribution(at point: TerrainFeaturePoint) -> TerrainFeatureContribution
}

enum TerrainFeatureMath {
    static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    static func smoothStep(edge0: Float, edge1: Float, _ value: Float) -> Float {
        guard edge0 != edge1 else {
            return value < edge0 ? 0 : 1
        }

        let amount = clamped01((value - edge0) / (edge1 - edge0))
        return amount * amount * (3 - 2 * amount)
    }

    static func distance(
        from point: TerrainFeaturePoint,
        toSegmentStart start: (x: Float, z: Float),
        end: (x: Float, z: Float)
    ) -> Float {
        let segmentX = end.x - start.x
        let segmentZ = end.z - start.z
        let lengthSquared = segmentX * segmentX + segmentZ * segmentZ

        guard lengthSquared > 0.0001 else {
            let dx = point.worldX - start.x
            let dz = point.worldZ - start.z
            return (dx * dx + dz * dz).squareRoot()
        }

        let projected = clamped01(
            ((point.worldX - start.x) * segmentX + (point.worldZ - start.z) * segmentZ) /
                lengthSquared
        )
        let closestX = start.x + segmentX * projected
        let closestZ = start.z + segmentZ * projected
        let dx = point.worldX - closestX
        let dz = point.worldZ - closestZ

        return (dx * dx + dz * dz).squareRoot()
    }

    static func orientedLocal(
        point: TerrainFeaturePoint,
        centerX: Float,
        centerZ: Float,
        angleRadians: Float
    ) -> (along: Float, cross: Float) {
        let dx = point.worldX - centerX
        let dz = point.worldZ - centerZ
        let cosAngle = Float(cos(Double(angleRadians)))
        let sinAngle = Float(sin(Double(angleRadians)))

        return (
            along: dx * cosAngle + dz * sinAngle,
            cross: -dx * sinAngle + dz * cosAngle
        )
    }
}
