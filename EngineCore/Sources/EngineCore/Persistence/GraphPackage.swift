public enum GraphPackageKind: String, CaseIterable, Codable, Sendable {
    case terrainRecipe
    case biomeGraph
    case propGenerator
    case materialGraph
    case audioGraph
    case fxGraph
    case uiTheme
    case characterRecipe
    case settlementRecipe
}

public struct GraphPoint: Hashable, Codable, Sendable {
    public let x: Float
    public let y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct GraphPackageNode: Hashable, Codable, Sendable {
    public let nodeID: String
    public let kind: String
    public let title: String
    public let position: GraphPoint
    public let parameters: [String: String]

    public init(
        nodeID: String,
        kind: String,
        title: String,
        position: GraphPoint = GraphPoint(x: 0, y: 0),
        parameters: [String: String] = [:]
    ) {
        precondition(!nodeID.isEmpty, "nodeID cannot be empty.")
        precondition(!kind.isEmpty, "kind cannot be empty.")
        precondition(!title.isEmpty, "title cannot be empty.")

        self.nodeID = nodeID
        self.kind = kind
        self.title = title
        self.position = position
        self.parameters = parameters
    }
}

public struct GraphPackageEdge: Hashable, Codable, Sendable {
    public let edgeID: String
    public let fromNodeID: String
    public let fromPort: String
    public let toNodeID: String
    public let toPort: String

    public init(
        edgeID: String,
        fromNodeID: String,
        fromPort: String,
        toNodeID: String,
        toPort: String
    ) {
        precondition(!edgeID.isEmpty, "edgeID cannot be empty.")
        precondition(!fromNodeID.isEmpty, "fromNodeID cannot be empty.")
        precondition(!fromPort.isEmpty, "fromPort cannot be empty.")
        precondition(!toNodeID.isEmpty, "toNodeID cannot be empty.")
        precondition(!toPort.isEmpty, "toPort cannot be empty.")

        self.edgeID = edgeID
        self.fromNodeID = fromNodeID
        self.fromPort = fromPort
        self.toNodeID = toNodeID
        self.toPort = toPort
    }
}

public struct PackageValidationReport: Hashable, Codable, Sendable {
    public let isValid: Bool
    public let issues: [String]

    public init(isValid: Bool, issues: [String] = []) {
        self.isValid = isValid
        self.issues = issues
    }
}

public struct GraphPackage: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldGraphPackage"

    public let format: String
    public let formatVersion: Int
    public let graphID: StableID
    public let kind: GraphPackageKind
    public let displayName: String
    public let schemaVersion: Int
    public let nodes: [GraphPackageNode]
    public let edges: [GraphPackageEdge]
    public let parameters: [String: String]
    public let revisionID: String
    public let contentHash: StableHash

    public init(
        format: String = Self.currentFormat,
        formatVersion: Int = 1,
        graphID: StableID,
        kind: GraphPackageKind,
        displayName: String,
        schemaVersion: Int = 1,
        nodes: [GraphPackageNode] = [],
        edges: [GraphPackageEdge] = [],
        parameters: [String: String] = [:],
        revisionID: String = "initial",
        contentHash: StableHash? = nil
    ) {
        precondition(formatVersion > 0, "formatVersion must be positive.")
        precondition(!displayName.isEmpty, "displayName cannot be empty.")
        precondition(schemaVersion > 0, "schemaVersion must be positive.")
        precondition(!revisionID.isEmpty, "revisionID cannot be empty.")

        self.format = format
        self.formatVersion = formatVersion
        self.graphID = graphID
        self.kind = kind
        self.displayName = displayName
        self.schemaVersion = schemaVersion
        self.nodes = nodes.sorted { $0.nodeID < $1.nodeID }
        self.edges = edges.sorted { $0.edgeID < $1.edgeID }
        self.parameters = parameters
        self.revisionID = revisionID
        self.contentHash = contentHash ?? Self.makeContentHash(
            graphID: graphID,
            kind: kind,
            schemaVersion: schemaVersion,
            nodes: self.nodes,
            edges: self.edges,
            parameters: parameters
        )
    }

    public var relativePath: String {
        "graphs/\(kind.rawValue)/\(graphID).isograph"
    }

    public var validationReport: PackageValidationReport {
        let nodeIDs = Set(nodes.map(\.nodeID))
        let duplicateNodes = nodeIDs.count != nodes.count
        let missingEdgeTargets = edges.filter {
            !nodeIDs.contains($0.fromNodeID) || !nodeIDs.contains($0.toNodeID)
        }

        var issues: [String] = []
        if duplicateNodes {
            issues.append("Graph contains duplicate node IDs.")
        }
        if !missingEdgeTargets.isEmpty {
            issues.append("Graph contains edges pointing to missing nodes.")
        }

        return PackageValidationReport(isValid: issues.isEmpty, issues: issues)
    }

    private static func makeContentHash(
        graphID: StableID,
        kind: GraphPackageKind,
        schemaVersion: Int,
        nodes: [GraphPackageNode],
        edges: [GraphPackageEdge],
        parameters: [String: String]
    ) -> StableHash {
        StableHash.make { builder in
            builder.combine(graphID.rawValue)
            builder.combine(kind.rawValue)
            builder.combine(schemaVersion)

            for node in nodes {
                builder.combine(node.nodeID)
                builder.combine(node.kind)
                builder.combine(node.title)
                builder.combine(node.position.x)
                builder.combine(node.position.y)

                for key in node.parameters.keys.sorted() {
                    builder.combine(key)
                    builder.combine(node.parameters[key] ?? "")
                }
            }

            for edge in edges {
                builder.combine(edge.edgeID)
                builder.combine(edge.fromNodeID)
                builder.combine(edge.fromPort)
                builder.combine(edge.toNodeID)
                builder.combine(edge.toPort)
            }

            for key in parameters.keys.sorted() {
                builder.combine(key)
                builder.combine(parameters[key] ?? "")
            }
        }
    }
}
