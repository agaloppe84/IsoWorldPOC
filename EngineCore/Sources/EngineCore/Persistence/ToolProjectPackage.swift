import Foundation

public enum ToolProjectKind: String, CaseIterable, Codable, Sendable {
    case terrainRecipeEditor
    case biomeGraphViewer
    case propGallery
    case materialViewer
    case lodDebugger
    case characterCustomizationLab
    case animationContactLab
    case fxPreviewEditor
    case audioGraphPreview
    case rpgWorldDNABrowser
    case settlementViewer
    case saveInspector
    case performanceHUD
    case seedGallery
    case snapshotDiff
}

public struct ToolProjectPackage: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldToolProjectPackage"

    public let format: String
    public let formatVersion: Int
    public let projectID: StableID
    public let kind: ToolProjectKind
    public let displayName: String
    public let saveVersion: SaveVersion
    public let createdAt: Date
    public let updatedAt: Date
    public let revisionID: String
    public let baseRevisionID: String?
    public let autosaveDraftPath: String?
    public let graphPackage: GraphPackage?
    public let assetPackageIDs: [StableID]
    public let metadata: [String: String]

    public init(
        format: String = Self.currentFormat,
        formatVersion: Int = 1,
        projectID: StableID,
        kind: ToolProjectKind,
        displayName: String,
        saveVersion: SaveVersion = .current,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        revisionID: String = "initial",
        baseRevisionID: String? = nil,
        autosaveDraftPath: String? = nil,
        graphPackage: GraphPackage? = nil,
        assetPackageIDs: [StableID] = [],
        metadata: [String: String] = [:]
    ) {
        precondition(formatVersion > 0, "formatVersion must be positive.")
        precondition(!displayName.isEmpty, "displayName cannot be empty.")
        precondition(!revisionID.isEmpty, "revisionID cannot be empty.")

        self.format = format
        self.formatVersion = formatVersion
        self.projectID = projectID
        self.kind = kind
        self.displayName = displayName
        self.saveVersion = saveVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.revisionID = revisionID
        self.baseRevisionID = baseRevisionID
        self.autosaveDraftPath = autosaveDraftPath
        self.graphPackage = graphPackage
        self.assetPackageIDs = Self.uniquedStable(assetPackageIDs)
        self.metadata = metadata
    }

    public var relativePath: String {
        "projects/\(kind.rawValue)/\(projectID).isoproj"
    }

    public var isAutosaveDraft: Bool {
        autosaveDraftPath != nil
    }

    public var validationReport: PackageValidationReport {
        var issues: [String] = []

        if updatedAt < createdAt {
            issues.append("Tool project updatedAt predates createdAt.")
        }

        if let graphPackage, !graphPackage.validationReport.isValid {
            issues.append("Embedded graph package is invalid.")
        }

        return PackageValidationReport(isValid: issues.isEmpty, issues: issues)
    }

    public func autosaved(
        at date: Date,
        draftPath: String,
        revisionID: String
    ) -> ToolProjectPackage {
        precondition(!draftPath.isEmpty, "draftPath cannot be empty.")

        return ToolProjectPackage(
            format: format,
            formatVersion: formatVersion,
            projectID: projectID,
            kind: kind,
            displayName: displayName,
            saveVersion: saveVersion,
            createdAt: createdAt,
            updatedAt: date,
            revisionID: revisionID,
            baseRevisionID: self.revisionID,
            autosaveDraftPath: draftPath,
            graphPackage: graphPackage,
            assetPackageIDs: assetPackageIDs,
            metadata: metadata
        )
    }

    private static func uniquedStable(_ values: [StableID]) -> [StableID] {
        var seen: Set<StableID> = []
        var result: [StableID] = []

        for value in values where seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }
}
