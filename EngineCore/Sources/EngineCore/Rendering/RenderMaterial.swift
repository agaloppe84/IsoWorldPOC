public struct TerrainTextureSlot: Equatable, Hashable, Codable, Sendable {
    public let materialKind: TerrainMaterialKind
    public let materialIdentifier: String
    public let textureLayerIndex: Int
    public let uvScale: Float
    public let debugName: String

    public init(
        materialKind: TerrainMaterialKind,
        materialIdentifier: String,
        textureLayerIndex: Int,
        uvScale: Float,
        debugName: String
    ) {
        precondition(textureLayerIndex >= 0, "textureLayerIndex must be non-negative.")
        precondition(uvScale > 0, "uvScale must be positive.")

        self.materialKind = materialKind
        self.materialIdentifier = materialIdentifier
        self.textureLayerIndex = textureLayerIndex
        self.uvScale = uvScale
        self.debugName = debugName
    }

    public init(material: TerrainMaterialDescriptor) {
        self.init(
            materialKind: material.kind,
            materialIdentifier: material.identifier,
            textureLayerIndex: Self.textureLayerIndex(for: material.kind),
            uvScale: Self.uvScale(for: material.kind),
            debugName: Self.debugName(for: material.kind)
        )
    }

    public static var allTerrainSlots: [TerrainTextureSlot] {
        TerrainMaterialKind.allCases.map { kind in
            TerrainTextureSlot(material: TerrainMaterialDescriptor.definition(for: kind))
        }
    }

    public static func slot(for kind: TerrainMaterialKind) -> TerrainTextureSlot {
        TerrainTextureSlot(material: TerrainMaterialDescriptor.definition(for: kind))
    }

    public static func textureLayerIndex(for kind: TerrainMaterialKind) -> Int {
        switch kind {
        case .grass:
            0
        case .rock:
            1
        case .dirt:
            2
        case .sand:
            3
        case .wetValley:
            4
        case .snow:
            5
        }
    }

    public static func uvScale(for kind: TerrainMaterialKind) -> Float {
        switch kind {
        case .grass:
            18
        case .rock:
            12
        case .dirt:
            16
        case .sand:
            14
        case .wetValley:
            13
        case .snow:
            10
        }
    }

    public static func debugName(for kind: TerrainMaterialKind) -> String {
        switch kind {
        case .grass:
            "Grass"
        case .rock:
            "Rock"
        case .dirt:
            "Dirt"
        case .sand:
            "Sand"
        case .wetValley:
            "Wet valley"
        case .snow:
            "Snow"
        }
    }
}

public struct RenderMaterial: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let debugName: String
    public let baseColor: BiomeColor
    public let roughness: Float
    public let terrainTextureSlot: TerrainTextureSlot?

    public init(
        identifier: String,
        debugName: String,
        baseColor: BiomeColor,
        roughness: Float,
        terrainTextureSlot: TerrainTextureSlot? = nil
    ) {
        self.identifier = identifier
        self.debugName = debugName
        self.baseColor = baseColor
        self.roughness = min(max(roughness, 0), 1)
        self.terrainTextureSlot = terrainTextureSlot
    }

    public static func terrain(_ material: TerrainMaterialDescriptor) -> RenderMaterial {
        terrain(
            kind: material.kind,
            identifier: material.identifier,
            baseColor: material.baseColor,
            roughness: material.roughness
        )
    }

    public static func terrain(
        kind: TerrainMaterialKind,
        identifier: String,
        baseColor: BiomeColor,
        roughness: Float
    ) -> RenderMaterial {
        RenderMaterial(
            identifier: identifier,
            debugName: TerrainTextureSlot.debugName(for: kind),
            baseColor: baseColor,
            roughness: roughness,
            terrainTextureSlot: TerrainTextureSlot(
                materialKind: kind,
                materialIdentifier: identifier,
                textureLayerIndex: TerrainTextureSlot.textureLayerIndex(for: kind),
                uvScale: TerrainTextureSlot.uvScale(for: kind),
                debugName: TerrainTextureSlot.debugName(for: kind)
            )
        )
    }
}
