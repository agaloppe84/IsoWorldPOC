public enum TerrainMaterialDebugMode: String, CaseIterable, Codable, Sendable {
    case normal
    case primaryBiome
    case secondaryBiome
    case blendWeight
    case splatLayerWeight
    case roughness
    case normalVector

    public var displayName: String {
        switch self {
        case .normal:
            "Normal"
        case .primaryBiome:
            "Primary biome"
        case .secondaryBiome:
            "Secondary biome"
        case .blendWeight:
            "Blend weight"
        case .splatLayerWeight:
            "Splat layer"
        case .roughness:
            "Roughness"
        case .normalVector:
            "Normal vector"
        }
    }
}

public struct RenderDebugOptions: Equatable, Codable, Sendable {
    public let showChunkBounds: Bool
    public let terrainMaterialDebugMode: TerrainMaterialDebugMode
    public let terrainSplatDebugLayerIndex: Int

    public init(
        showChunkBounds: Bool = false,
        terrainMaterialDebugMode: TerrainMaterialDebugMode = .normal,
        terrainSplatDebugLayerIndex: Int = 0
    ) {
        self.showChunkBounds = showChunkBounds
        self.terrainMaterialDebugMode = terrainMaterialDebugMode
        self.terrainSplatDebugLayerIndex = Self.clampedSplatLayerIndex(terrainSplatDebugLayerIndex)
    }

    private static func clampedSplatLayerIndex(_ value: Int) -> Int {
        min(max(value, 0), TerrainMaterialSplat.maxLayerCount - 1)
    }
}

public struct RenderWorldSnapshot: Equatable, Codable, Sendable {
    public let camera: CameraRenderState
    public let lighting: LightingState
    public let chunks: [RenderChunk]
    public let debugOptions: RenderDebugOptions

    public var visibleChunkCount: Int {
        chunks.filter(\.isVisible).count
    }

    public var approximateTriangleCount: Int {
        chunks.reduce(0) { total, chunk in
            guard chunk.isVisible else {
                return total
            }

            return total + chunk.approximateTriangleCount
        }
    }

    public var visiblePropCount: Int {
        chunks.reduce(0) { total, chunk in
            guard chunk.isVisible else {
                return total
            }

            return total + chunk.props.filter(\.isVisible).count
        }
    }

    public init(
        camera: CameraRenderState,
        lighting: LightingState = .defaultDay,
        chunks: [RenderChunk],
        debugOptions: RenderDebugOptions = RenderDebugOptions()
    ) {
        self.camera = camera
        self.lighting = lighting
        self.chunks = chunks
        self.debugOptions = debugOptions
    }
}
