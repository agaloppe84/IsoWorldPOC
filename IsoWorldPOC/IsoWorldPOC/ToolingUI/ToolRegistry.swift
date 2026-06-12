import EngineCore
import Foundation

struct ToolRegistry {
    static let defaultSeedText = "isoworld-seed-001"
    static let defaultToolID = "terrain.recipe.editor"

    static let v1 = ToolRegistry(descriptors: [
        ToolDescriptor(
            id: "terrain.viewer",
            name: "Terrain Viewer",
            category: .terrain,
            summary: "Inspect V1 terrain fields and sample density.",
            systemImage: "mountain.2",
            capabilities: [.preview, .validation, .presets]
        ),
        ToolDescriptor(
            id: "biome.viewer",
            name: "Biome Viewer",
            category: .biomes,
            summary: "Inspect biome weights, transitions and dominant zones.",
            systemImage: "leaf",
            capabilities: [.preview, .validation, .presets]
        ),
        ToolDescriptor(
            id: "prop.gallery",
            name: "Prop Gallery",
            category: .props,
            summary: "Browse natural V1 prop families and deterministic variants.",
            systemImage: "shippingbox",
            capabilities: [.preview, .validation, .presets]
        ),
        ToolDescriptor(
            id: "material.viewer",
            name: "Material Viewer",
            category: .materials,
            summary: "Inspect terrain material slots and PBR preview layers.",
            systemImage: "paintpalette",
            capabilities: [.preview, .validation, .presets]
        ),
        ToolDescriptor(
            id: "lod.debugger",
            name: "LOD Debugger",
            category: .lod,
            summary: "Inspect chunk LOD selection and visible budget decisions.",
            systemImage: "square.stack.3d.up",
            capabilities: [.preview, .validation]
        ),
        ToolDescriptor(
            id: "seed.explorer",
            name: "Seed Explorer",
            category: .world,
            summary: "Inspect deterministic seed derivation without opening a world.",
            systemImage: "number",
            capabilities: [.preview, .validation, .presets]
        ),
    ])

    static let v2 = ToolRegistry(descriptors: [
        ToolDescriptor(
            id: "terrain.recipe.editor",
            name: "Terrain Recipe Editor",
            category: .terrain,
            summary: "Author terrain fields, features and hydrology recipes.",
            systemImage: "mountain.2",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "biome.graph.viewer",
            name: "Biome Graph Viewer",
            category: .biomes,
            summary: "Inspect weights, ecotones, sub-biomes and transition rules.",
            systemImage: "leaf",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics]
        ),
        ToolDescriptor(
            id: "prop.gallery",
            name: "Prop Gallery",
            category: .props,
            summary: "Browse prop families, genomes, placement rules and budgets.",
            systemImage: "shippingbox",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "material.viewer",
            name: "Material Viewer",
            category: .materials,
            summary: "Inspect PBR parameters, texture slots and surface state hooks.",
            systemImage: "paintpalette",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics]
        ),
        ToolDescriptor(
            id: "lod.debugger",
            name: "LOD Debugger",
            category: .lod,
            summary: "Inspect chunk, prop and terrain LOD budgets and hysteresis.",
            systemImage: "square.stack.3d.up",
            capabilities: [.preview, .validation, .diagnostics]
        ),
        ToolDescriptor(
            id: "character.customization.lab",
            name: "Character Customization Lab",
            category: .characters,
            summary: "Inspect CharacterDNA, body parameters, sockets and overrides.",
            systemImage: "person.crop.rectangle.stack",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "animation.contact.lab",
            name: "Animation Contact Lab",
            category: .animation,
            summary: "Inspect contact patches, foot IK, slope response and events.",
            systemImage: "figure.walk.motion",
            capabilities: [.preview, .validation, .persistence, .diagnostics]
        ),
        ToolDescriptor(
            id: "fx.preview.editor",
            name: "FX Preview Editor",
            category: .fx,
            summary: "Preview event-driven particles, decals and budget variants.",
            systemImage: "sparkles",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "audio.graph.preview",
            name: "Audio Graph Preview",
            category: .audio,
            summary: "Preview procedural audio recipes, buses and event matrices.",
            systemImage: "waveform",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "rpg.world.dna.browser",
            name: "RPG World DNA Browser",
            category: .rpg,
            summary: "Inspect world laws, factions, objectives and rule contracts.",
            systemImage: "map",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics]
        ),
        ToolDescriptor(
            id: "settlement.viewer",
            name: "Settlement Viewer",
            category: .settlements,
            summary: "Inspect settlement sites, massing, recipes and terrain support.",
            systemImage: "building.2",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics]
        ),
        ToolDescriptor(
            id: "save.inspector",
            name: "Save Inspector",
            category: .saves,
            summary: "Inspect manifests, deltas, snapshots and package references.",
            systemImage: "externaldrive",
            capabilities: [.preview, .validation, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "performance.hud",
            name: "Performance HUD",
            category: .performance,
            summary: "Inspect frame budgets, renderer counters and telemetry gates.",
            systemImage: "speedometer",
            capabilities: [.preview, .validation, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "seed.gallery",
            name: "Seed Gallery",
            category: .world,
            summary: "Curate golden seeds, extremes and deterministic preview cases.",
            systemImage: "number",
            capabilities: [.preview, .validation, .presets, .persistence, .diagnostics, .export]
        ),
        ToolDescriptor(
            id: "snapshot.diff",
            name: "Snapshot Diff",
            category: .snapshots,
            summary: "Compare preview snapshots, revisions and generated reports.",
            systemImage: "square.on.square.dashed",
            capabilities: [.preview, .validation, .persistence, .diagnostics, .export]
        ),
    ])

    let descriptors: [ToolDescriptor]

    var defaultDescriptor: ToolDescriptor {
        descriptor(for: Self.defaultToolID) ?? descriptors[0]
    }

    var categories: [ToolCategory] {
        ToolCategory.allCases.filter { category in
            descriptors.contains { $0.category == category }
        }
    }

    func descriptor(for id: String) -> ToolDescriptor? {
        descriptors.first { $0.id == id }
    }

    func tools(in category: ToolCategory?) -> [ToolDescriptor] {
        guard let category else {
            return descriptors
        }

        return descriptors.filter { $0.category == category }
    }

    func makeDefaultDocument(
        for descriptor: ToolDescriptor,
        seedText: String = Self.defaultSeedText
    ) -> ToolDocument {
        ToolDocument(
            toolID: descriptor.id,
            seedText: normalizedSeedText(seedText),
            presetName: defaultPresetName(for: descriptor),
            sampleCount: defaultSampleCount(for: descriptor)
        )
    }

    func validate(document: ToolDocument) -> ToolValidationReport {
        var issues: [ToolValidationIssue] = []

        if descriptor(for: document.toolID) == nil {
            issues.append(ToolValidationIssue(
                id: "unknown-tool",
                severity: .error,
                message: "Unknown tool document.",
                fixHint: "Select a registered tool or migrate the document toolID."
            ))
        }

        if document.seedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ToolValidationIssue(
                id: "fallback-seed",
                severity: .warning,
                message: "Empty seed resolves to \(Self.defaultSeedText).",
                fixHint: "Set an explicit seed before exporting a production package."
            ))
        }

        if document.sampleCount < 1 {
            issues.append(ToolValidationIssue(
                id: "sample-count-min",
                severity: .error,
                message: "Sample count must be at least 1.",
                fixHint: "Raise sample count to 1 or more."
            ))
        } else if document.sampleCount > 128 {
            issues.append(ToolValidationIssue(
                id: "sample-count-high",
                severity: .warning,
                message: "High sample counts should stay out of the main world loop.",
                fixHint: "Keep heavy sampling in tool previews, jobs or cached exports."
            ))
        }

        if document.revisionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ToolValidationIssue(
                id: "empty-revision",
                severity: .error,
                message: "Revision ID is required for package-backed tools.",
                fixHint: "Create a revision snapshot before saving the document."
            ))
        }

        let invalidReferences = document.packageReferences.filter {
            !$0.hasSuffix(".isoproj") && !$0.hasSuffix(".isoasset") && !$0.hasSuffix(".isograph")
        }
        if !invalidReferences.isEmpty {
            issues.append(ToolValidationIssue(
                id: "invalid-package-reference",
                severity: .warning,
                message: "Package references should point to .isoproj, .isoasset or .isograph files.",
                fixHint: "Use Step 23 package extensions for dependency references."
            ))
        }

        issues.append(ToolValidationIssue(
            id: "isolated-preview",
            severity: .info,
            message: "Preview snapshot is isolated from WorldRuntime.",
            fixHint: "Keep previews snapshot/report based unless an explicit runtime bridge is added."
        ))

        return ToolValidationReport(toolID: document.toolID, issues: issues)
    }

    func makePreviewSnapshot(
        for descriptor: ToolDescriptor,
        document: ToolDocument
    ) -> ToolPreviewSnapshot {
        let worldSeed = worldSeed(from: document.seedText)
        let documentHash = StableHash.make { builder in
            builder.combine(descriptor.id)
            builder.combine(document.presetName)
            builder.combine(document.sampleCount)
        }
        let previewID = StableID.make(
            worldSeed: worldSeed,
            domain: SeedDomain("tool-preview"),
            values: [documentHash.value]
        )

        return ToolPreviewSnapshot(
            id: previewID,
            toolName: descriptor.name,
            worldSeed: worldSeed,
            status: .ready,
            progress: 1,
            render: nil,
            message: "\(descriptor.name) preview ready."
        )
    }

    func worldSeed(from seedText: String) -> WorldSeed {
        WorldSeed(StableHash.make { builder in
            builder.combine(normalizedSeedText(seedText))
        }.value)
    }

    func normalizedSeedText(_ seedText: String) -> String {
        let trimmedSeed = seedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSeed.isEmpty ? Self.defaultSeedText : trimmedSeed
    }

    private func defaultPresetName(for descriptor: ToolDescriptor) -> String {
        switch descriptor.id {
        case "terrain.recipe.editor":
            "Terrain recipe V2"
        case "biome.graph.viewer":
            "Biome graph V2"
        case "terrain.viewer":
            "Terrain baseline"
        case "biome.viewer":
            "Biome blend"
        case "prop.gallery":
            "Prop catalog V2"
        case "material.viewer":
            "PBR preview"
        case "lod.debugger":
            "LOD budget V2"
        case "character.customization.lab":
            "Character DNA V2"
        case "animation.contact.lab":
            "Contact lab V2"
        case "fx.preview.editor":
            "FX matrix V2"
        case "audio.graph.preview":
            "Audio graph V2"
        case "rpg.world.dna.browser":
            "World RPG DNA V2"
        case "settlement.viewer":
            "Settlement plan V2"
        case "save.inspector":
            "Save package V2"
        case "performance.hud":
            "Performance budget V2"
        case "seed.gallery":
            "Golden seeds V2"
        case "snapshot.diff":
            "Snapshot diff V2"
        case "seed.explorer":
            "Seed trace"
        default:
            "Default"
        }
    }

    private func defaultSampleCount(for descriptor: ToolDescriptor) -> Int {
        switch descriptor.id {
        case "prop.gallery":
            48
        case "lod.debugger":
            25
        case "performance.hud", "snapshot.diff":
            16
        default:
            32
        }
    }
}
