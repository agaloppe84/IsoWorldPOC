public enum RenderChunkDebugState: String, Codable, Sendable {
    case current
    case active
    case generating
    case inactive
}

public struct RenderChunkDebugBounds: Equatable, Codable, Sendable {
    public let coordinate: ChunkCoordinate
    public let origin: WorldPosition
    public let size: PropVector3
    public let state: RenderChunkDebugState

    public init(
        coordinate: ChunkCoordinate,
        origin: WorldPosition,
        size: PropVector3,
        state: RenderChunkDebugState
    ) {
        self.coordinate = coordinate
        self.origin = origin
        self.size = size
        self.state = state
    }
}

public struct RenderChunk: Equatable, Codable, Sendable {
    public let coordinate: ChunkCoordinate
    public let origin: WorldPosition
    public let terrainGeometry: TerrainGeometryBuffers
    public let biome: Biome
    public let terrainMaterial: TerrainMaterialDescriptor
    public let props: [RenderProp]
    public let debugBounds: RenderChunkDebugBounds?
    public let isVisible: Bool
    public let approximateTriangleCount: Int

    public init(
        coordinate: ChunkCoordinate,
        origin: WorldPosition,
        terrainGeometry: TerrainGeometryBuffers,
        biome: Biome,
        terrainMaterial: TerrainMaterialDescriptor,
        props: [RenderProp] = [],
        debugBounds: RenderChunkDebugBounds? = nil,
        isVisible: Bool = true,
        approximateTriangleCount: Int
    ) {
        self.coordinate = coordinate
        self.origin = origin
        self.terrainGeometry = terrainGeometry
        self.biome = biome
        self.terrainMaterial = terrainMaterial
        self.props = props
        self.debugBounds = debugBounds
        self.isVisible = isVisible
        self.approximateTriangleCount = approximateTriangleCount
    }
}
