import EngineCore
import Foundation

struct ToolRegistry {
    static let defaultSeedText = "isoworld-seed-001"
    static let defaultToolID = "terrain.viewer"

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
                message: "Unknown tool document."
            ))
        }

        if document.seedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ToolValidationIssue(
                id: "fallback-seed",
                severity: .warning,
                message: "Empty seed resolves to \(Self.defaultSeedText)."
            ))
        }

        if document.sampleCount < 1 {
            issues.append(ToolValidationIssue(
                id: "sample-count-min",
                severity: .error,
                message: "Sample count must be at least 1."
            ))
        } else if document.sampleCount > 128 {
            issues.append(ToolValidationIssue(
                id: "sample-count-high",
                severity: .warning,
                message: "High sample counts should stay out of the main world loop."
            ))
        }

        issues.append(ToolValidationIssue(
            id: "isolated-preview",
            severity: .info,
            message: "Preview snapshot is isolated from WorldRuntime."
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
        case "terrain.viewer":
            "Terrain baseline"
        case "biome.viewer":
            "Biome blend"
        case "prop.gallery":
            "Natural props"
        case "material.viewer":
            "PBR preview"
        case "lod.debugger":
            "Chunk budget"
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
        default:
            32
        }
    }
}
