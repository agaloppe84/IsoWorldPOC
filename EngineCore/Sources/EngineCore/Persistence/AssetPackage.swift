public enum AssetPackageType: String, CaseIterable, Codable, Sendable {
    case proceduralPropGenerator
    case material
    case audioRecipe
    case fxRecipe
    case characterPreset
    case settlementRecipe
    case graphBundle
    case toolPreset
}

public struct AssetSourceManifest: Hashable, Codable, Sendable {
    public let graphPath: String?
    public let parameterPath: String?
    public let sourceAssetPaths: [String]

    public init(
        graphPath: String? = nil,
        parameterPath: String? = nil,
        sourceAssetPaths: [String] = []
    ) {
        self.graphPath = graphPath
        self.parameterPath = parameterPath
        self.sourceAssetPaths = sourceAssetPaths.filter { !$0.isEmpty }.sorted()
    }
}

public struct RuntimeExportManifest: Hashable, Codable, Sendable {
    public let path: String
    public let contentHash: StableHash
    public let generatorVersionsHash: StableHash

    public init(
        path: String,
        contentHash: StableHash,
        generatorVersionsHash: StableHash = GeneratorVersionTable.current.persistenceHash
    ) {
        precondition(!path.isEmpty, "path cannot be empty.")

        self.path = path
        self.contentHash = contentHash
        self.generatorVersionsHash = generatorVersionsHash
    }
}

public struct AssetPackage: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldAssetPackage"

    public let format: String
    public let formatVersion: Int
    public let assetID: StableID
    public let type: AssetPackageType
    public let displayName: String
    public let schemaVersion: Int
    public let tags: [GameplayTag]
    public let source: AssetSourceManifest
    public let runtimeExport: RuntimeExportManifest?
    public let revisionID: String
    public let baseRevisionID: String?
    public let contentHash: StableHash

    public init(
        format: String = Self.currentFormat,
        formatVersion: Int = 1,
        assetID: StableID,
        type: AssetPackageType,
        displayName: String,
        schemaVersion: Int = 1,
        tags: [GameplayTag] = [],
        source: AssetSourceManifest = AssetSourceManifest(),
        runtimeExport: RuntimeExportManifest? = nil,
        revisionID: String = "initial",
        baseRevisionID: String? = nil,
        contentHash: StableHash? = nil
    ) {
        precondition(formatVersion > 0, "formatVersion must be positive.")
        precondition(!displayName.isEmpty, "displayName cannot be empty.")
        precondition(schemaVersion > 0, "schemaVersion must be positive.")
        precondition(!revisionID.isEmpty, "revisionID cannot be empty.")

        self.format = format
        self.formatVersion = formatVersion
        self.assetID = assetID
        self.type = type
        self.displayName = displayName
        self.schemaVersion = schemaVersion
        self.tags = tags.uniquedStable()
        self.source = source
        self.runtimeExport = runtimeExport
        self.revisionID = revisionID
        self.baseRevisionID = baseRevisionID
        self.contentHash = contentHash ?? Self.makeContentHash(
            assetID: assetID,
            type: type,
            schemaVersion: schemaVersion,
            tags: self.tags,
            source: source,
            runtimeExport: runtimeExport
        )
    }

    public var relativePath: String {
        "assets/\(type.rawValue)/\(assetID).isoasset"
    }

    public var validationReport: PackageValidationReport {
        var issues: [String] = []

        if source.graphPath == nil && source.parameterPath == nil && source.sourceAssetPaths.isEmpty {
            issues.append("Asset package has no source manifest.")
        }

        return PackageValidationReport(isValid: issues.isEmpty, issues: issues)
    }

    private static func makeContentHash(
        assetID: StableID,
        type: AssetPackageType,
        schemaVersion: Int,
        tags: [GameplayTag],
        source: AssetSourceManifest,
        runtimeExport: RuntimeExportManifest?
    ) -> StableHash {
        StableHash.make { builder in
            builder.combine(assetID.rawValue)
            builder.combine(type.rawValue)
            builder.combine(schemaVersion)

            for tag in tags {
                builder.combine(tag.rawValue)
            }

            builder.combine(source.graphPath ?? "")
            builder.combine(source.parameterPath ?? "")
            for path in source.sourceAssetPaths {
                builder.combine(path)
            }

            if let runtimeExport {
                builder.combine(runtimeExport.path)
                builder.combine(runtimeExport.contentHash.value)
                builder.combine(runtimeExport.generatorVersionsHash.value)
            }
        }
    }
}
