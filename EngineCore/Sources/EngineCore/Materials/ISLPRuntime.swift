public enum MaterialCompatibilityTag: String, CaseIterable, Codable, Sendable {
    case terrain
    case natural
    case organic
    case mineral
    case granular
    case wettable
    case snowReactive
    case dustReactive
    case mossReactive
}

public struct IsoTextureSetID: RawRepresentable, Equatable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty, "IsoTextureSetID cannot be empty.")
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }
}

public struct IsoTextureSetDescriptor: Equatable, Hashable, Codable, Sendable {
    public let id: IsoTextureSetID
    public let materialID: MaterialID
    public let debugName: String
    public let bindings: [SurfaceTextureBinding]
    public let packsORM: Bool

    public init(
        id: IsoTextureSetID,
        materialID: MaterialID,
        debugName: String,
        bindings: [SurfaceTextureBinding],
        packsORM: Bool = true
    ) {
        self.id = id
        self.materialID = materialID
        self.debugName = debugName
        self.bindings = bindings
        self.packsORM = packsORM
    }

    public static func from(surface: SurfaceDescriptor) -> IsoTextureSetDescriptor {
        IsoTextureSetDescriptor(
            id: IsoTextureSetID("\(surface.materialID.rawValue).textures"),
            materialID: surface.materialID,
            debugName: surface.debugName,
            bindings: surface.textureBindings,
            packsORM: surface.textureBindings.contains { $0.role == .orm }
        )
    }
}

public struct BiomeMaterialPalette: Equatable, Hashable, Codable, Sendable {
    public let biomeType: BiomeType
    public let dominantMaterialID: MaterialID
    public let accentMaterialIDs: [MaterialID]
    public let compatibilityTags: [MaterialCompatibilityTag]
    public let tintStrength: Float

    public init(
        biomeType: BiomeType,
        dominantMaterialID: MaterialID,
        accentMaterialIDs: [MaterialID],
        compatibilityTags: [MaterialCompatibilityTag],
        tintStrength: Float
    ) {
        self.biomeType = biomeType
        self.dominantMaterialID = dominantMaterialID
        self.accentMaterialIDs = accentMaterialIDs
        self.compatibilityTags = Array(Set(compatibilityTags)).sorted { $0.rawValue < $1.rawValue }
        self.tintStrength = Self.clamped01(tintStrength)
    }

    public static func productionBaseline(renderDNA: WorldRenderDNA) -> [BiomeMaterialPalette] {
        BiomeType.allCases.map { biomeType in
            let biome = Biome.definition(for: biomeType)
            return BiomeMaterialPalette(
                biomeType: biomeType,
                dominantMaterialID: MaterialID(biome.terrainMaterial.identifier),
                accentMaterialIDs: accentMaterials(for: biome),
                compatibilityTags: tags(for: biome.terrainMaterial.kind),
                tintStrength: 0.10 + renderDNA.biomeMaterialMutation * 0.32
            )
        }
    }

    private static func accentMaterials(for biome: Biome) -> [MaterialID] {
        switch biome.type {
        case .temperateForest:
            [.init("terrain.material.grass"), .init("terrain.material.dirt"), .init("terrain.material.mud")]
        case .grassland:
            [.init("terrain.material.grass"), .init("terrain.material.dirt")]
        case .desert:
            [.init("terrain.material.sand"), .init("terrain.material.rock")]
        case .mountain:
            [.init("terrain.material.rock"), .init("terrain.material.snow")]
        case .marsh:
            [.init("terrain.material.mud"), .init("terrain.material.grass")]
        case .taiga:
            [.init("terrain.material.snow"), .init("terrain.material.dirt"), .init("terrain.material.rock")]
        case .coast:
            [.init("terrain.material.sand"), .init("terrain.material.mud")]
        case .freshwater:
            [.init("terrain.material.mud"), .init("terrain.material.rock")]
        }
    }

    private static func tags(for kind: TerrainMaterialKind) -> [MaterialCompatibilityTag] {
        switch kind {
        case .grass:
            [.terrain, .natural, .organic, .wettable, .mossReactive]
        case .rock:
            [.terrain, .natural, .mineral, .wettable, .snowReactive, .mossReactive]
        case .dirt:
            [.terrain, .natural, .granular, .wettable, .dustReactive]
        case .sand:
            [.terrain, .natural, .granular, .dustReactive]
        case .mud:
            [.terrain, .natural, .organic, .wettable]
        case .snow:
            [.terrain, .natural, .snowReactive]
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct IsoMaterialRuntimeTable: Equatable, Codable, Sendable {
    public let materials: [IsoMaterialRuntime]
    public let textureSets: [IsoTextureSetDescriptor]
    public let biomePalettes: [BiomeMaterialPalette]

    public init(
        materials: [IsoMaterialRuntime],
        textureSets: [IsoTextureSetDescriptor]? = nil,
        biomePalettes: [BiomeMaterialPalette] = []
    ) {
        self.materials = materials
        self.textureSets = textureSets ?? materials.map { runtime in
            IsoTextureSetDescriptor.from(surface: runtime.descriptor)
        }
        self.biomePalettes = biomePalettes
    }

    public static func terrainBaseline(
        renderDNA: WorldRenderDNA = WorldRenderDNA.make(worldSeed: WorldSeed(1)),
        surfaceState: SurfaceState = .dry
    ) -> IsoMaterialRuntimeTable {
        let materials = TerrainMaterialKind.allCases.map { kind in
            IsoMaterialRuntime.terrain(
                TerrainMaterialDescriptor.definition(for: kind),
                surfaceState: surfaceState
            )
        }

        return IsoMaterialRuntimeTable(
            materials: materials,
            biomePalettes: BiomeMaterialPalette.productionBaseline(renderDNA: renderDNA)
        )
    }

    public func runtimeMaterial(for materialID: MaterialID) -> IsoMaterialRuntime? {
        materials.first { $0.materialID == materialID }
    }

    public func textureSet(for materialID: MaterialID) -> IsoTextureSetDescriptor? {
        textureSets.first { $0.materialID == materialID }
    }

    public func validationReport() -> ISLPValidationReport {
        ISLPMaterialValidator.validate(self)
    }
}

public enum ISLPValidationSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct ISLPValidationIssue: Equatable, Hashable, Codable, Sendable {
    public let severity: ISLPValidationSeverity
    public let code: String
    public let materialID: MaterialID?
    public let message: String

    public init(
        severity: ISLPValidationSeverity,
        code: String,
        materialID: MaterialID? = nil,
        message: String
    ) {
        self.severity = severity
        self.code = code
        self.materialID = materialID
        self.message = message
    }
}

public struct ISLPValidationReport: Equatable, Codable, Sendable {
    public let materialCount: Int
    public let textureSetCount: Int
    public let biomePaletteCount: Int
    public let issues: [ISLPValidationIssue]

    public var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    public var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    public var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    public init(
        materialCount: Int,
        textureSetCount: Int,
        biomePaletteCount: Int,
        issues: [ISLPValidationIssue]
    ) {
        self.materialCount = materialCount
        self.textureSetCount = textureSetCount
        self.biomePaletteCount = biomePaletteCount
        self.issues = issues
    }
}

public enum ISLPMaterialValidator {
    public static func validate(_ table: IsoMaterialRuntimeTable) -> ISLPValidationReport {
        var issues: [ISLPValidationIssue] = []
        var seenMaterialIDs = Set<MaterialID>()

        for material in table.materials {
            if !seenMaterialIDs.insert(material.materialID).inserted {
                issues.append(ISLPValidationIssue(
                    severity: .error,
                    code: "material.duplicate-id",
                    materialID: material.materialID,
                    message: "Material runtime table contains duplicate material id."
                ))
            }

            validateParameters(material.resolvedParameters, materialID: material.materialID, issues: &issues)
            validateTextureRoles(material.descriptor, issues: &issues)
        }

        for textureSet in table.textureSets {
            let roles = Set(textureSet.bindings.map(\.role))

            if !roles.isSuperset(of: [.baseColor, .normal, .orm]) {
                issues.append(ISLPValidationIssue(
                    severity: .error,
                    code: "texture-set.missing-pbr-role",
                    materialID: textureSet.materialID,
                    message: "Texture set must expose baseColor, normal and packed ORM roles."
                ))
            }
        }

        return ISLPValidationReport(
            materialCount: table.materials.count,
            textureSetCount: table.textureSets.count,
            biomePaletteCount: table.biomePalettes.count,
            issues: issues
        )
    }

    private static func validateParameters(
        _ parameters: MaterialParameterBlock,
        materialID: MaterialID,
        issues: inout [ISLPValidationIssue]
    ) {
        if parameters.baseColor.red < 0 || parameters.baseColor.red > 1 ||
            parameters.baseColor.green < 0 || parameters.baseColor.green > 1 ||
            parameters.baseColor.blue < 0 || parameters.baseColor.blue > 1 {
            issues.append(ISLPValidationIssue(
                severity: .error,
                code: "material.albedo.out-of-range",
                materialID: materialID,
                message: "Base color channels must stay in 0...1."
            ))
        }

        if parameters.roughness < 0.04 || parameters.roughness > 0.98 {
            issues.append(ISLPValidationIssue(
                severity: .warning,
                code: "material.roughness.extreme",
                materialID: materialID,
                message: "Roughness is legal but near an extreme value."
            ))
        }

        if parameters.metallic != 0 && parameters.metallic != 1 {
            issues.append(ISLPValidationIssue(
                severity: .warning,
                code: "material.metallic.fractional",
                materialID: materialID,
                message: "Metallic should remain binary or tightly controlled."
            ))
        }
    }

    private static func validateTextureRoles(
        _ descriptor: SurfaceDescriptor,
        issues: inout [ISLPValidationIssue]
    ) {
        let roles = Set(descriptor.textureBindings.map(\.role))

        guard descriptor.terrainMaterialKind != nil else {
            return
        }

        if !roles.contains(.baseColor) || !roles.contains(.normal) || !roles.contains(.orm) {
            issues.append(ISLPValidationIssue(
                severity: .error,
                code: "surface.missing-pbr-role",
                materialID: descriptor.materialID,
                message: "Terrain surface must bind baseColor, normal and ORM roles."
            ))
        }
    }
}
