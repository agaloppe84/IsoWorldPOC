public enum SurfaceShadingModel: String, CaseIterable, Codable, Sendable {
    case opaquePBR
}

public enum SurfaceTextureRole: String, CaseIterable, Codable, Sendable {
    case baseColor
    case normal
    case orm
}

public struct SurfaceTextureBinding: Equatable, Hashable, Codable, Sendable {
    public let role: SurfaceTextureRole
    public let terrainTextureSlot: TerrainTextureSlot?

    public init(
        role: SurfaceTextureRole,
        terrainTextureSlot: TerrainTextureSlot? = nil
    ) {
        self.role = role
        self.terrainTextureSlot = terrainTextureSlot
    }
}

public struct SurfaceDescriptor: Equatable, Hashable, Codable, Sendable {
    public let materialID: MaterialID
    public let debugName: String
    public let shadingModel: SurfaceShadingModel
    public let parameters: MaterialParameterBlock
    public let textureBindings: [SurfaceTextureBinding]
    public let terrainMaterialKind: TerrainMaterialKind?
    public let supportsTriplanar: Bool
    public let triplanarSlopeThreshold: Float

    public init(
        materialID: MaterialID,
        debugName: String,
        shadingModel: SurfaceShadingModel = .opaquePBR,
        parameters: MaterialParameterBlock,
        textureBindings: [SurfaceTextureBinding] = [],
        terrainMaterialKind: TerrainMaterialKind? = nil,
        supportsTriplanar: Bool = false,
        triplanarSlopeThreshold: Float = 0.55
    ) {
        self.materialID = materialID
        self.debugName = debugName
        self.shadingModel = shadingModel
        self.parameters = parameters
        self.textureBindings = textureBindings
        self.terrainMaterialKind = terrainMaterialKind
        self.supportsTriplanar = supportsTriplanar
        self.triplanarSlopeThreshold = min(max(triplanarSlopeThreshold, 0), 1)
    }

    public static func terrain(_ material: TerrainMaterialDescriptor) -> SurfaceDescriptor {
        let pbrSlots = TerrainPBRTextureSlots(material: material)

        return SurfaceDescriptor(
            materialID: MaterialID(material.identifier),
            debugName: TerrainTextureSlot.debugName(for: material.kind),
            parameters: .terrain(material),
            textureBindings: [
                SurfaceTextureBinding(role: .baseColor, terrainTextureSlot: pbrSlots.albedo),
                SurfaceTextureBinding(role: .normal, terrainTextureSlot: pbrSlots.normal),
                SurfaceTextureBinding(
                    role: .orm,
                    terrainTextureSlot: pbrSlots.metallicAmbientOcclusion
                ),
            ],
            terrainMaterialKind: material.kind,
            supportsTriplanar: true,
            triplanarSlopeThreshold: 0.55
        )
    }
}
