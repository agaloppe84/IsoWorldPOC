public enum TerrainTextureMap: String, CaseIterable, Codable, Sendable {
    case albedo
    case normal
    case roughness
    case metallicAmbientOcclusion

    public var debugName: String {
        switch self {
        case .albedo:
            "Albedo"
        case .normal:
            "Normal"
        case .roughness:
            "Roughness"
        case .metallicAmbientOcclusion:
            "Metallic/AO"
        }
    }
}

public struct TerrainTextureSlot: Equatable, Hashable, Codable, Sendable {
    public let map: TerrainTextureMap
    public let materialKind: TerrainMaterialKind
    public let materialIdentifier: String
    public let textureLayerIndex: Int
    public let uvScale: Float
    public let debugName: String

    public init(
        map: TerrainTextureMap = .albedo,
        materialKind: TerrainMaterialKind,
        materialIdentifier: String,
        textureLayerIndex: Int,
        uvScale: Float,
        debugName: String
    ) {
        precondition(textureLayerIndex >= 0, "textureLayerIndex must be non-negative.")
        precondition(uvScale > 0, "uvScale must be positive.")

        self.map = map
        self.materialKind = materialKind
        self.materialIdentifier = materialIdentifier
        self.textureLayerIndex = textureLayerIndex
        self.uvScale = uvScale
        self.debugName = debugName
    }

    public init(material: TerrainMaterialDescriptor, map: TerrainTextureMap = .albedo) {
        self.init(
            map: map,
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

    public static var allTerrainPBRSlots: [TerrainTextureSlot] {
        TerrainMaterialKind.allCases.flatMap { kind in
            TerrainTextureMap.allCases.map { map in
                TerrainTextureSlot(
                    material: TerrainMaterialDescriptor.definition(for: kind),
                    map: map
                )
            }
        }
    }

    public static func slot(for kind: TerrainMaterialKind) -> TerrainTextureSlot {
        slot(for: kind, map: .albedo)
    }

    public static func slot(
        for kind: TerrainMaterialKind,
        map: TerrainTextureMap
    ) -> TerrainTextureSlot {
        TerrainTextureSlot(
            material: TerrainMaterialDescriptor.definition(for: kind),
            map: map
        )
    }

    public static func pbrSlots(for kind: TerrainMaterialKind) -> TerrainPBRTextureSlots {
        TerrainPBRTextureSlots(material: TerrainMaterialDescriptor.definition(for: kind))
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

public struct TerrainPBRTextureSlots: Equatable, Hashable, Codable, Sendable {
    public let albedo: TerrainTextureSlot
    public let normal: TerrainTextureSlot
    public let roughness: TerrainTextureSlot
    public let metallicAmbientOcclusion: TerrainTextureSlot

    public var allSlots: [TerrainTextureSlot] {
        [
            albedo,
            normal,
            roughness,
            metallicAmbientOcclusion,
        ]
    }

    public init(
        albedo: TerrainTextureSlot,
        normal: TerrainTextureSlot,
        roughness: TerrainTextureSlot,
        metallicAmbientOcclusion: TerrainTextureSlot
    ) {
        self.albedo = albedo
        self.normal = normal
        self.roughness = roughness
        self.metallicAmbientOcclusion = metallicAmbientOcclusion
    }

    public init(material: TerrainMaterialDescriptor) {
        self.init(
            albedo: TerrainTextureSlot(material: material, map: .albedo),
            normal: TerrainTextureSlot(material: material, map: .normal),
            roughness: TerrainTextureSlot(material: material, map: .roughness),
            metallicAmbientOcclusion: TerrainTextureSlot(
                material: material,
                map: .metallicAmbientOcclusion
            )
        )
    }
}

public struct RenderMaterial: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let debugName: String
    public let baseColor: BiomeColor
    public let roughness: Float
    public let terrainTextureSlot: TerrainTextureSlot?
    public let terrainPBRTextureSlots: TerrainPBRTextureSlots?

    public init(
        identifier: String,
        debugName: String,
        baseColor: BiomeColor,
        roughness: Float,
        terrainTextureSlot: TerrainTextureSlot? = nil,
        terrainPBRTextureSlots: TerrainPBRTextureSlots? = nil
    ) {
        self.identifier = identifier
        self.debugName = debugName
        self.baseColor = baseColor
        self.roughness = min(max(roughness, 0), 1)
        self.terrainTextureSlot = terrainTextureSlot
        self.terrainPBRTextureSlots = terrainPBRTextureSlots
    }

    public var materialID: MaterialID {
        MaterialID(identifier)
    }

    public var surfaceDescriptor: SurfaceDescriptor {
        if let terrainTextureSlot {
            return SurfaceDescriptor.terrain(TerrainMaterialDescriptor(
                kind: terrainTextureSlot.materialKind,
                identifier: identifier,
                baseColor: baseColor,
                roughness: roughness
            ))
        }

        return SurfaceDescriptor(
            materialID: materialID,
            debugName: debugName,
            parameters: MaterialParameterBlock(
                baseColor: baseColor,
                roughness: roughness
            )
        )
    }

    public var runtimeMaterial: IsoMaterialRuntime {
        IsoMaterialRuntime(descriptor: surfaceDescriptor)
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
        let material = TerrainMaterialDescriptor(
            kind: kind,
            identifier: identifier,
            baseColor: baseColor,
            roughness: roughness
        )
        let pbrSlots = TerrainPBRTextureSlots(material: material)

        return RenderMaterial(
            identifier: identifier,
            debugName: TerrainTextureSlot.debugName(for: kind),
            baseColor: baseColor,
            roughness: roughness,
            terrainTextureSlot: pbrSlots.albedo,
            terrainPBRTextureSlots: pbrSlots
        )
    }
}
