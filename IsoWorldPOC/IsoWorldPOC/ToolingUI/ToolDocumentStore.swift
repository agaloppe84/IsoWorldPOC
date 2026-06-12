import EngineCore
import Foundation

struct ToolDocumentStore {
    private let fileWriter: AtomicFileWriter

    init(fileWriter: AtomicFileWriter = AtomicFileWriter()) {
        self.fileWriter = fileWriter
    }

    func makeProjectPackage(
        for document: ToolDocument,
        descriptor: ToolDescriptor,
        registry: ToolRegistry,
        now: Date = Date()
    ) -> ToolProjectPackage {
        let graphPackage = makeGraphPackage(
            for: document,
            descriptor: descriptor,
            registry: registry
        )
        let assetPackage = makeAssetPackage(
            for: document,
            descriptor: descriptor,
            registry: registry,
            graphPackage: graphPackage
        )

        return ToolProjectPackage(
            projectID: stableID(
                domain: "tool-project",
                descriptor: descriptor,
                document: document,
                registry: registry
            ),
            kind: projectKind(for: descriptor),
            displayName: descriptor.name,
            createdAt: now,
            updatedAt: now,
            revisionID: document.revisionID,
            graphPackage: graphPackage,
            assetPackageIDs: [assetPackage.assetID],
            metadata: [
                "toolID": descriptor.id,
                "seed": registry.normalizedSeedText(document.seedText),
                "preset": document.presetName,
                "sampleCount": "\(document.sampleCount)",
            ]
        )
    }

    func makeGraphPackage(
        for document: ToolDocument,
        descriptor: ToolDescriptor,
        registry: ToolRegistry
    ) -> GraphPackage {
        let seedNode = GraphPackageNode(
            nodeID: "seed",
            kind: "input.seed",
            title: registry.normalizedSeedText(document.seedText),
            position: GraphPoint(x: 0, y: 0)
        )
        let presetNode = GraphPackageNode(
            nodeID: "preset",
            kind: "tool.preset",
            title: document.presetName,
            position: GraphPoint(x: 180, y: 0),
            parameters: [
                "sampleCount": "\(document.sampleCount)",
                "toolID": descriptor.id,
            ]
        )
        let outputNode = GraphPackageNode(
            nodeID: "preview",
            kind: "tool.preview",
            title: descriptor.name,
            position: GraphPoint(x: 360, y: 0)
        )

        return GraphPackage(
            graphID: stableID(
                domain: "tool-graph",
                descriptor: descriptor,
                document: document,
                registry: registry
            ),
            kind: graphKind(for: descriptor),
            displayName: "\(descriptor.name) Graph",
            nodes: [seedNode, presetNode, outputNode],
            edges: [
                GraphPackageEdge(
                    edgeID: "seed-to-preset",
                    fromNodeID: "seed",
                    fromPort: "value",
                    toNodeID: "preset",
                    toPort: "seed"
                ),
                GraphPackageEdge(
                    edgeID: "preset-to-preview",
                    fromNodeID: "preset",
                    fromPort: "recipe",
                    toNodeID: "preview",
                    toPort: "input"
                ),
            ],
            parameters: [
                "revisionID": document.revisionID,
                "notesHash": StableHash.make { builder in
                    builder.combine(document.notes)
                }.description,
            ],
            revisionID: document.revisionID
        )
    }

    func makeAssetPackage(
        for document: ToolDocument,
        descriptor: ToolDescriptor,
        registry: ToolRegistry,
        graphPackage: GraphPackage? = nil
    ) -> AssetPackage {
        let graphPackage = graphPackage ?? makeGraphPackage(
            for: document,
            descriptor: descriptor,
            registry: registry
        )

        return AssetPackage(
            assetID: stableID(
                domain: "tool-asset",
                descriptor: descriptor,
                document: document,
                registry: registry
            ),
            type: assetType(for: descriptor),
            displayName: "\(descriptor.name) Asset",
            tags: [
                GameplayTag("tool.\(descriptor.category.rawValue)"),
                GameplayTag("tool.\(descriptor.id.replacingOccurrences(of: ".", with: "_"))"),
            ],
            source: AssetSourceManifest(
                graphPath: graphPackage.relativePath,
                parameterPath: "parameters/\(descriptor.id)/\(document.id).json",
                sourceAssetPaths: document.packageReferences
            ),
            revisionID: document.revisionID
        )
    }

    func autosaveDraft(
        for package: ToolProjectPackage,
        draftPath: String,
        now: Date = Date()
    ) -> ToolProjectPackage {
        package.autosaved(
            at: now,
            draftPath: draftPath,
            revisionID: "\(package.revisionID)-autosave"
        )
    }

    func saveProject(_ package: ToolProjectPackage, to url: URL) throws {
        try fileWriter.writeJSON(package, to: url)
    }

    func openProject(from url: URL) throws -> ToolProjectPackage {
        try fileWriter.readJSON(ToolProjectPackage.self, from: url)
    }

    func saveAsset(_ package: AssetPackage, to url: URL) throws {
        try fileWriter.writeJSON(package, to: url)
    }

    func openAsset(from url: URL) throws -> AssetPackage {
        try fileWriter.readJSON(AssetPackage.self, from: url)
    }

    func saveGraph(_ package: GraphPackage, to url: URL) throws {
        try fileWriter.writeJSON(package, to: url)
    }

    func openGraph(from url: URL) throws -> GraphPackage {
        try fileWriter.readJSON(GraphPackage.self, from: url)
    }

    func runtimeExportManifest(
        for package: AssetPackage,
        path: String
    ) -> RuntimeExportManifest {
        RuntimeExportManifest(
            path: path,
            contentHash: package.contentHash
        )
    }

    private func stableID(
        domain: SeedDomain,
        descriptor: ToolDescriptor,
        document: ToolDocument,
        registry: ToolRegistry
    ) -> StableID {
        StableID.make(
            worldSeed: registry.worldSeed(from: document.seedText),
            domain: domain,
            values: [
                StableHash.make { builder in
                    builder.combine(descriptor.id)
                    builder.combine(document.id.uuidString)
                    builder.combine(document.revisionID)
                }.value,
            ]
        )
    }

    private func projectKind(for descriptor: ToolDescriptor) -> ToolProjectKind {
        switch descriptor.id {
        case "terrain.recipe.editor":
            .terrainRecipeEditor
        case "biome.graph.viewer":
            .biomeGraphViewer
        case "prop.gallery":
            .propGallery
        case "material.viewer":
            .materialViewer
        case "lod.debugger":
            .lodDebugger
        case "character.customization.lab":
            .characterCustomizationLab
        case "animation.contact.lab":
            .animationContactLab
        case "fx.preview.editor":
            .fxPreviewEditor
        case "audio.graph.preview":
            .audioGraphPreview
        case "rpg.world.dna.browser":
            .rpgWorldDNABrowser
        case "settlement.viewer":
            .settlementViewer
        case "save.inspector":
            .saveInspector
        case "performance.hud":
            .performanceHUD
        case "snapshot.diff":
            .snapshotDiff
        default:
            .seedGallery
        }
    }

    private func graphKind(for descriptor: ToolDescriptor) -> GraphPackageKind {
        switch descriptor.category {
        case .terrain, .lod, .performance, .saves, .snapshots, .world:
            .terrainRecipe
        case .biomes:
            .biomeGraph
        case .props:
            .propGenerator
        case .materials:
            .materialGraph
        case .characters, .animation, .rpg:
            .characterRecipe
        case .fx:
            .fxGraph
        case .audio:
            .audioGraph
        case .settlements:
            .settlementRecipe
        }
    }

    private func assetType(for descriptor: ToolDescriptor) -> AssetPackageType {
        switch descriptor.category {
        case .props:
            .proceduralPropGenerator
        case .materials:
            .material
        case .audio:
            .audioRecipe
        case .fx:
            .fxRecipe
        case .characters, .animation:
            .characterPreset
        case .settlements:
            .settlementRecipe
        case .biomes, .terrain, .lod, .world, .rpg, .saves, .performance, .snapshots:
            .toolPreset
        }
    }
}
