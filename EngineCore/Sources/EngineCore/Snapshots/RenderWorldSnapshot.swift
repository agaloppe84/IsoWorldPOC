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
    public let renderTerrain: Bool
    public let renderProps: Bool
    public let renderPlayer: Bool
    public let terrainMaterialDebugMode: TerrainMaterialDebugMode
    public let terrainSplatDebugLayerIndex: Int

    public init(
        showChunkBounds: Bool = false,
        renderTerrain: Bool = true,
        renderProps: Bool = true,
        renderPlayer: Bool = true,
        terrainMaterialDebugMode: TerrainMaterialDebugMode = .normal,
        terrainSplatDebugLayerIndex: Int = 0
    ) {
        self.showChunkBounds = showChunkBounds
        self.renderTerrain = renderTerrain
        self.renderProps = renderProps
        self.renderPlayer = renderPlayer
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
    public let environment: RenderEnvironmentState
    public let chunks: [RenderChunk]
    public let debugOptions: RenderDebugOptions
    public let fx: FXFrameSnapshot
    public let ui: UIFrameSnapshot

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

    public var visibleFXPrimitiveCount: Int {
        fx.particles.count + fx.decals.count
    }

    public var hasVisibleHUD: Bool {
        ui.hasVisibleHUD
    }

    public init(
        camera: CameraRenderState,
        lighting: LightingState = .defaultDay,
        environment: RenderEnvironmentState = .default,
        chunks: [RenderChunk],
        debugOptions: RenderDebugOptions = RenderDebugOptions(),
        fx: FXFrameSnapshot = .empty,
        ui: UIFrameSnapshot = .empty
    ) {
        self.camera = camera
        self.lighting = lighting
        self.environment = environment
        self.chunks = chunks
        self.debugOptions = debugOptions
        self.fx = fx
        self.ui = ui
    }

    private enum CodingKeys: String, CodingKey {
        case camera
        case lighting
        case environment
        case chunks
        case debugOptions
        case fx
        case ui
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            camera: try container.decode(CameraRenderState.self, forKey: .camera),
            lighting: try container.decodeIfPresent(LightingState.self, forKey: .lighting) ?? .defaultDay,
            environment: try container.decodeIfPresent(RenderEnvironmentState.self, forKey: .environment) ?? .default,
            chunks: try container.decode([RenderChunk].self, forKey: .chunks),
            debugOptions: try container.decodeIfPresent(RenderDebugOptions.self, forKey: .debugOptions) ?? RenderDebugOptions(),
            fx: try container.decodeIfPresent(FXFrameSnapshot.self, forKey: .fx) ?? .empty,
            ui: try container.decodeIfPresent(UIFrameSnapshot.self, forKey: .ui) ?? .empty
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(camera, forKey: .camera)
        try container.encode(lighting, forKey: .lighting)
        try container.encode(environment, forKey: .environment)
        try container.encode(chunks, forKey: .chunks)
        try container.encode(debugOptions, forKey: .debugOptions)
        try container.encode(fx, forKey: .fx)
        try container.encode(ui, forKey: .ui)
    }
}
