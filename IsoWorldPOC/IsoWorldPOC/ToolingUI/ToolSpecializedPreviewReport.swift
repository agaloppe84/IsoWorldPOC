import EngineCore
import Foundation
import SwiftUI

struct ToolPreviewMetric: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let value: String

    init(id: String, title: String, value: String) {
        self.id = id
        self.title = title
        self.value = value
    }
}

struct ToolPreviewSection: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let metrics: [ToolPreviewMetric]

    init(id: String, title: String, metrics: [ToolPreviewMetric]) {
        self.id = id
        self.title = title
        self.metrics = metrics
    }
}

struct ToolSpecializedPreviewReport: Codable, Equatable, Identifiable {
    let toolID: String
    let title: String
    let summary: String
    let isSpecialized: Bool
    let sections: [ToolPreviewSection]

    var id: String {
        toolID
    }

    func metricValue(for metricID: String) -> String? {
        for section in sections {
            if let metric = section.metrics.first(where: { $0.id == metricID }) {
                return metric.value
            }
        }

        return nil
    }
}

struct ToolSpecializedPreviewBuilder {
    static let specializedToolIDs: Set<String> = [
        "terrain.recipe.editor",
        "biome.graph.viewer",
        "prop.gallery",
        "material.viewer",
        "lod.debugger",
        "save.inspector",
        "seed.gallery",
    ]

    private let documentStore: ToolDocumentStore

    init(documentStore: ToolDocumentStore = ToolDocumentStore()) {
        self.documentStore = documentStore
    }

    func makeReport(
        for descriptor: ToolDescriptor,
        document: ToolDocument,
        registry: ToolRegistry
    ) -> ToolSpecializedPreviewReport {
        let context = ToolPreviewReportContext(
            descriptor: descriptor,
            document: document,
            registry: registry
        )

        switch descriptor.id {
        case "terrain.recipe.editor":
            return terrainReport(context)
        case "biome.graph.viewer":
            return biomeReport(context)
        case "prop.gallery":
            return propReport(context)
        case "material.viewer":
            return materialReport(context)
        case "lod.debugger":
            return lodReport(context)
        case "save.inspector":
            return saveInspectorReport(context)
        case "seed.gallery":
            return seedGalleryReport(context)
        default:
            return genericReport(context)
        }
    }

    private func terrainReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let graph = TerrainFeatureGraph.make(seed: context.worldSeed)
        let originQuery = graph.features(intersecting: .origin)
        let graphHash = StableHash.make { builder in
            builder.combine(graph.seed)
            builder.combine(graph.featureCount)
            builder.combine(graph.rivers.count)
            builder.combine(graph.lakes.count)
            builder.combine(graph.mountainRanges.count)
            builder.combine(graph.cliffBands.count)
        }

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Terrain FeatureGraph",
            summary: "Terrain features, hydrology and chunk seam inputs for \(context.normalizedSeedText).",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "terrain.features",
                    title: "FeatureGraph",
                    metrics: [
                        metric("terrain.feature.count", "Features", graph.featureCount),
                        metric("terrain.river.count", "Rivers", graph.rivers.count),
                        metric("terrain.lake.count", "Lakes", graph.lakes.count),
                        metric("terrain.mountain.count", "Mountain ranges", graph.mountainRanges.count),
                        metric("terrain.cliff.count", "Cliff bands", graph.cliffBands.count),
                        metric("terrain.graph.hash", "Graph hash", graphHash.description),
                    ]
                ),
                ToolPreviewSection(
                    id: "terrain.origin-chunk",
                    title: "Origin chunk query",
                    metrics: [
                        metric("terrain.origin.feature.count", "Intersecting features", originQuery.featureCount),
                        metric("terrain.origin.rivers", "Rivers", originQuery.rivers.count),
                        metric("terrain.origin.lakes", "Lakes", originQuery.lakes.count),
                        metric("terrain.sample.budget", "Sample budget", context.document.sampleCount),
                    ]
                ),
            ]
        )
    }

    private func biomeReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let biomes = BiomeType.allCases.map(Biome.definition(for:))
        let subBiomeCount = BiomeType.allCases
            .flatMap(SubBiomeDefinition.defaults(for:))
            .count
        let ecotoneRules = EcotoneRule.defaultRules
        let densestBiome = biomes.max {
            $0.propDensityMultiplier < $1.propDensityMultiplier
        }
        let materialCount = Set(biomes.map(\.terrainMaterial.identifier)).count
        let averageSoftness = ecotoneRules.isEmpty
            ? Float(0)
            : ecotoneRules.reduce(Float(0)) { $0 + $1.softnessMeters } / Float(ecotoneRules.count)

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Biome Graph",
            summary: "Biome weights, ecotones and sub-biome contracts for \(context.normalizedSeedText).",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "biome.contracts",
                    title: "Biome contracts",
                    metrics: [
                        metric("biome.count", "Biomes", biomes.count),
                        metric("biome.subbiome.count", "Sub-biomes", subBiomeCount),
                        metric("biome.material.count", "Material bindings", materialCount),
                        metric("biome.densest", "Highest prop density", densestBiome?.displayName ?? "none"),
                    ]
                ),
                ToolPreviewSection(
                    id: "biome.ecotones",
                    title: "Ecotones",
                    metrics: [
                        metric("biome.ecotone.count", "Rules", ecotoneRules.count),
                        metric("biome.ecotone.avg-softness", "Avg softness m", decimal(averageSoftness)),
                        metric("biome.ecotone.curve", "Blend curve", ecotoneRules.first?.materialBlendCurve ?? "none"),
                    ]
                ),
            ]
        )
    }

    private func propReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let catalog = PropCatalog.naturalV1
        let strongestRule = catalog.rules.max { $0.baseWeight < $1.baseWeight }
        let tunedBiomeWeights = catalog.rules.reduce(0) { $0 + $1.biomeWeights.count }
        let averageBaseWeight = catalog.rules.isEmpty
            ? Float(0)
            : catalog.rules.reduce(Float(0)) { $0 + $1.baseWeight } / Float(catalog.rules.count)

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Prop Gallery",
            summary: "Prop families, placement rules and deterministic sample budget.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "prop.catalog",
                    title: "Catalog",
                    metrics: [
                        metric("prop.catalog.identifier", "Identifier", catalog.identifier),
                        metric("prop.type.count", "Types", catalog.supportedTypes.count),
                        metric("prop.rule.count", "Rules", catalog.rules.count),
                        metric("prop.sample.budget", "Sample budget", context.document.sampleCount),
                    ]
                ),
                ToolPreviewSection(
                    id: "prop.placement",
                    title: "Placement",
                    metrics: [
                        metric("prop.biome-weight.count", "Biome weights", tunedBiomeWeights),
                        metric("prop.avg-base-weight", "Avg base weight", decimal(averageBaseWeight)),
                        metric("prop.strongest-type", "Strongest type", strongestRule?.type.rawValue ?? "none"),
                    ]
                ),
            ]
        )
    }

    private func materialReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let materials = TerrainMaterialKind.allCases
            .map(TerrainMaterialDescriptor.definition(for:))
        let surfaces = materials.map(SurfaceDescriptor.terrain(_:))
        let pbrSlotCount = TerrainTextureSlot.allTerrainPBRSlots.count
        let triplanarCount = surfaces.filter(\.supportsTriplanar).count
        let dryGrass = SurfaceDescriptor
            .terrain(TerrainMaterialDescriptor.definition(for: .grass))
            .parameters
        let wetGrass = SurfaceState(wetness: 1).applying(to: dryGrass)

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Material Viewer",
            summary: "Terrain material slots, PBR texture roles and surface state hooks.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "material.slots",
                    title: "Slots",
                    metrics: [
                        metric("material.kind.count", "Material kinds", materials.count),
                        metric("material.texture.map.count", "Texture maps", TerrainTextureMap.allCases.count),
                        metric("material.pbr.slot.count", "PBR slots", pbrSlotCount),
                        metric("material.triplanar.count", "Triplanar surfaces", triplanarCount),
                    ]
                ),
                ToolPreviewSection(
                    id: "material.surface-state",
                    title: "Surface state",
                    metrics: [
                        metric("material.shading-model", "Shading", SurfaceShadingModel.opaquePBR.rawValue),
                        metric("material.grass.roughness", "Grass roughness", decimal(dryGrass.roughness)),
                        metric("material.wet-grass.roughness", "Wet roughness", decimal(wetGrass.roughness)),
                    ]
                ),
            ]
        )
    }

    private func lodReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let policy = LODPolicy.chunkBaseline(chunkWorldExtent: 16)

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "LOD Budget",
            summary: "Chunk distance thresholds, draw budgets and hysteresis guardrails.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "lod.thresholds",
                    title: "Distance thresholds",
                    metrics: [
                        metric("lod.threshold.lod0", "LOD0 max", decimal(policy.thresholds.lod0MaxDistance)),
                        metric("lod.threshold.lod1", "LOD1 max", decimal(policy.thresholds.lod1MaxDistance)),
                        metric("lod.threshold.lod2", "LOD2 max", decimal(policy.thresholds.lod2MaxDistance)),
                        metric("lod.threshold.visible", "Visible max", decimal(policy.thresholds.visibleMaxDistance)),
                    ]
                ),
                ToolPreviewSection(
                    id: "lod.budget",
                    title: "Budgets",
                    metrics: [
                        metric("lod.budget.visible-chunks", "Visible chunks", policy.budget.maxVisibleChunks),
                        metric("lod.budget.terrain-draws", "Terrain draws", policy.budget.maxTerrainDrawCalls),
                        metric("lod.budget.prop-draws", "Prop draws", policy.budget.maxPropDrawCalls),
                        metric("lod.hysteresis.margin", "Hysteresis margin", decimal(policy.hysteresis.distanceMargin)),
                    ]
                ),
            ]
        )
    }

    private func saveInspectorReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let project = documentStore.makeProjectPackage(
            for: context.document,
            descriptor: context.descriptor,
            registry: context.registry
        )
        let graph = documentStore.makeGraphPackage(
            for: context.document,
            descriptor: context.descriptor,
            registry: context.registry
        )
        let asset = documentStore.makeAssetPackage(
            for: context.document,
            descriptor: context.descriptor,
            registry: context.registry,
            graphPackage: graph
        )
        let runtimeExport = documentStore.runtimeExportManifest(
            for: asset,
            path: "runtime/tools/\(context.descriptor.id).json"
        )

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Save Inspector",
            summary: "Package manifest, graph and runtime export contracts for the selected tool.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "save.packages",
                    title: "Packages",
                    metrics: [
                        metric("save.project.path", "Project", project.relativePath),
                        metric("save.graph.path", "Graph", graph.relativePath),
                        metric("save.asset.path", "Asset", asset.relativePath),
                        metric("save.references.count", "References", context.document.packageReferences.count),
                    ]
                ),
                ToolPreviewSection(
                    id: "save.validation",
                    title: "Validation",
                    metrics: [
                        metric("save.project.valid", "Project valid", yesNo(project.validationReport.isValid)),
                        metric("save.graph.valid", "Graph valid", yesNo(graph.validationReport.isValid)),
                        metric("save.asset.valid", "Asset valid", yesNo(asset.validationReport.isValid)),
                        metric("save.runtime.export", "Runtime export", runtimeExport.path),
                    ]
                ),
            ]
        )
    }

    private func seedGalleryReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let namedSeeds = GoldenWorldSeeds.named
        let seedMatch = namedSeeds.first { $0.seed == context.worldSeed }
        let derivedPreviewSeed = context.worldSeed.derived(
            domain: SeedDomain("tool.seed-gallery.preview"),
            values: [UInt64(context.document.sampleCount)]
        )

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Seed Gallery",
            summary: "Golden seed corpus and deterministic preview derivation.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "seed.corpus",
                    title: "Corpus",
                    metrics: [
                        metric("seed.golden.count", "Golden seeds", namedSeeds.count),
                        metric("seed.current.name", "Current match", seedMatch?.name ?? "custom"),
                        metric("seed.current.value", "World seed", context.worldSeed.value),
                        metric("seed.sample.budget", "Sample budget", context.document.sampleCount),
                    ]
                ),
                ToolPreviewSection(
                    id: "seed.preview",
                    title: "Preview derivation",
                    metrics: [
                        metric("seed.normalized-text", "Normalized seed", context.normalizedSeedText),
                        metric("seed.derived.preview", "Preview seed", derivedPreviewSeed.value),
                    ]
                ),
            ]
        )
    }

    private func genericReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Generic package preview",
            summary: "Package-backed tool surface awaiting its specialized V2 editor.",
            isSpecialized: false,
            sections: [
                ToolPreviewSection(
                    id: "generic.document",
                    title: "Document",
                    metrics: [
                        metric("generic.category", "Category", context.descriptor.category.displayName),
                        metric("generic.seed", "Seed", context.normalizedSeedText),
                        metric("generic.samples", "Samples", context.document.sampleCount),
                        metric("generic.references", "References", context.document.packageReferences.count),
                    ]
                ),
            ]
        )
    }
}

struct ToolSpecializedPreviewReportView: View {
    let report: ToolSpecializedPreviewReport

    private let columns = [
        GridItem(.adaptive(minimum: 138, maximum: 220), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(report.title)
                            .font(.headline)
                        Label(
                            report.isSpecialized ? "Specialized" : "Generic",
                            systemImage: report.isSpecialized ? "checkmark.seal" : "clock"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(report.isSpecialized ? .green : .secondary)
                    }

                    Text(report.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ForEach(report.sections) { section in
                VStack(alignment: .leading, spacing: 9) {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(section.metrics) { metric in
                            metricView(metric)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metricView(_ metric: ToolPreviewMetric) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(metric.title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(metric.value.isEmpty ? "none" : metric.value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToolPreviewReportContext {
    let descriptor: ToolDescriptor
    let document: ToolDocument
    let registry: ToolRegistry
    let normalizedSeedText: String
    let worldSeed: WorldSeed

    init(
        descriptor: ToolDescriptor,
        document: ToolDocument,
        registry: ToolRegistry
    ) {
        self.descriptor = descriptor
        self.document = document
        self.registry = registry
        self.normalizedSeedText = registry.normalizedSeedText(document.seedText)
        self.worldSeed = registry.worldSeed(from: document.seedText)
    }
}

private func metric(_ id: String, _ title: String, _ value: Int) -> ToolPreviewMetric {
    metric(id, title, "\(value)")
}

private func metric(_ id: String, _ title: String, _ value: UInt64) -> ToolPreviewMetric {
    metric(id, title, "\(value)")
}

private func metric(_ id: String, _ title: String, _ value: String) -> ToolPreviewMetric {
    ToolPreviewMetric(id: id, title: title, value: value)
}

private func decimal(_ value: Float, digits: Int = 2) -> String {
    String(format: "%.\(digits)f", Double(value))
}

private func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
}
