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

struct ToolGoldenSeedValidationResult: Codable, Equatable, Identifiable {
    let name: String
    let seedValue: UInt64
    let issues: [String]

    var id: String {
        name
    }

    var isValid: Bool {
        issues.isEmpty
    }
}

struct ToolGoldenSeedValidationReport: Codable, Equatable {
    let checkedDomains: [String]
    let results: [ToolGoldenSeedValidationResult]

    var isValid: Bool {
        results.allSatisfy(\.isValid)
    }

    var checkedSeedCount: Int {
        results.count
    }

    var checkedDomainCount: Int {
        checkedDomains.count
    }

    var issueCount: Int {
        results.reduce(0) { $0 + $1.issues.count }
    }
}

struct ToolGoldenSeedValidationRunner {
    static let checkedDomains = [
        "terrain",
        "characters",
        "animation",
        "fx",
        "audio",
        "rpg",
        "settlements",
        "lod",
    ]

    func validate() -> ToolGoldenSeedValidationReport {
        let results = GoldenWorldSeeds.named.map { goldenSeed in
            ToolGoldenSeedValidationResult(
                name: goldenSeed.name,
                seedValue: goldenSeed.seed.value,
                issues: issues(for: goldenSeed)
            )
        }

        return ToolGoldenSeedValidationReport(
            checkedDomains: Self.checkedDomains,
            results: results
        )
    }

    private func issues(for goldenSeed: GoldenWorldSeed) -> [String] {
        let worldSeed = goldenSeed.seed
        var issues: [String] = []

        let terrainGraph = TerrainFeatureGraph.make(seed: worldSeed)
        if terrainGraph.featureCount == 0 {
            issues.append("Terrain FeatureGraph is empty.")
        }

        let character = CharacterCustomizationSave.defaultPlayer(worldSeed: worldSeed)
        if !character.isRegenerable {
            issues.append("Character customization save is not regenerable.")
        }

        let walkClip = AnimationClip.humanoidWalk(body: character.characterDNA.body)
        if walkClip.contactWindows.count < 2 {
            issues.append("Humanoid walk clip lacks bilateral contact windows.")
        }

        let fxRecipe = FXRecipe()
        if fxRecipe.definitions.isEmpty {
            issues.append("FX recipe has no definitions.")
        }

        let audioResolver = AudioRecipeResolver()
        if audioResolver.recipes.isEmpty {
            issues.append("Audio recipe resolver has no recipes.")
        }

        let rpgDNA = WorldRPGDNA.make(worldSeed: worldSeed)
        let ruleset = WorldRuleset.make(worldSeed: worldSeed, dna: rpgDNA)
        if !ruleset.validationReport.isPlayable {
            issues.append("RPG ruleset is not playable.")
        }

        let settlementRecipe = SettlementRecipe.makeV1(
            worldSeed: worldSeed,
            ruleset: ruleset,
            biomeType: .grassland
        )
        if settlementRecipe.desiredBuildingCount <= 0 {
            issues.append("Settlement recipe has no buildings.")
        }

        let lodPolicy = LODPolicy.chunkBaseline(chunkWorldExtent: 16)
        if lodPolicy.budget.maxVisibleChunks <= 0 {
            issues.append("LOD visible chunk budget is empty.")
        }

        return issues
    }
}

struct ToolSpecializedPreviewBuilder {
    static let specializedToolIDs: Set<String> = [
        "terrain.recipe.editor",
        "biome.graph.viewer",
        "prop.gallery",
        "material.viewer",
        "lod.debugger",
        "character.customization.lab",
        "animation.contact.lab",
        "fx.preview.editor",
        "audio.graph.preview",
        "rpg.world.dna.browser",
        "settlement.viewer",
        "save.inspector",
        "performance.hud",
        "seed.gallery",
        "snapshot.diff",
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
        case "character.customization.lab":
            return characterReport(context)
        case "animation.contact.lab":
            return animationReport(context)
        case "fx.preview.editor":
            return fxReport(context)
        case "audio.graph.preview":
            return audioReport(context)
        case "rpg.world.dna.browser":
            return rpgReport(context)
        case "settlement.viewer":
            return settlementReport(context)
        case "save.inspector":
            return saveInspectorReport(context)
        case "performance.hud":
            return performanceReport(context)
        case "seed.gallery":
            return seedGalleryReport(context)
        case "snapshot.diff":
            return snapshotDiffReport(context)
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

    private func characterReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let save = CharacterCustomizationSave.defaultPlayer(worldSeed: context.worldSeed)
        let dna = save.characterDNA
        let body = dna.body
        let mesh = dna.meshDescriptor

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Character DNA",
            summary: "Body parameters, sockets, equipment and save override contracts.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "character.dna",
                    title: "DNA",
                    metrics: [
                        metric("character.schema", "Schema", Int(dna.schemaVersion)),
                        metric("character.role", "Role", dna.identity.role.rawValue),
                        metric("character.height", "Height m", decimal(body.heightMeters)),
                        metric("character.walk-speed", "Walk m/s", decimal(body.naturalWalkSpeedMetersPerSecond)),
                    ]
                ),
                ToolPreviewSection(
                    id: "character.runtime",
                    title: "Runtime contracts",
                    metrics: [
                        metric("character.joints", "Joints", dna.skeleton.joints.count),
                        metric("character.sockets", "Sockets", dna.sockets.count),
                        metric("character.equipment", "Equipped items", dna.equipment.items.count),
                        metric("character.mesh.vertices", "LOD0 vertices", mesh.estimatedVertexCountLOD0),
                        metric("character.save.regenerable", "Regenerable", yesNo(save.isRegenerable)),
                    ]
                ),
            ]
        )
    }

    private func animationReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let body = CharacterDNA.makePlayer(worldSeed: context.worldSeed).body
        let idle = AnimationClip.humanoidIdle(body: body)
        let walk = AnimationClip.humanoidWalk(body: body)
        let ikSolver = FootIKSolver()
        let profiles = TerrainMaterialKind.allCases
            .map(SurfaceMaterialContactProfile.profile(for:))
        let averageFriction = profiles.isEmpty
            ? Float(0)
            : profiles.reduce(Float(0)) { $0 + $1.baseFriction } / Float(profiles.count)

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Animation Contact Lab",
            summary: "Humanoid clips, foot contacts, IK limits and surface response contracts.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "animation.clips",
                    title: "Clips",
                    metrics: [
                        metric("animation.clip.count", "Clips", 2),
                        metric("animation.idle.duration", "Idle duration", decimal(idle.duration)),
                        metric("animation.walk.duration", "Walk duration", decimal(walk.duration)),
                        metric("animation.walk.root-motion", "Walk root m", decimal(walk.rootMotionMetersPerCycle)),
                        metric("animation.contact.windows", "Contact windows", walk.contactWindows.count),
                    ]
                ),
                ToolPreviewSection(
                    id: "animation.ik",
                    title: "IK and surfaces",
                    metrics: [
                        metric("animation.ik.sole-offset", "Sole offset", decimal(ikSolver.soleOffset, digits: 3)),
                        metric("animation.ik.pelvis-max", "Pelvis max", decimal(ikSolver.maxPelvisCompensation)),
                        metric("animation.surface.profiles", "Surface profiles", profiles.count),
                        metric("animation.surface.avg-friction", "Avg friction", decimal(averageFriction)),
                    ]
                ),
            ]
        )
    }

    private func fxReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let recipe = FXRecipe()
        let definitions = Array(recipe.definitions.values)
        let billboardCount = definitions.filter { $0.kind == .billboardSprite }.count
        let decalCount = definitions.filter { $0.kind == .decal }.count
        let budget = FXBudget.v1Realtime

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "FX Preview Editor",
            summary: "Event-driven FX definitions, blend modes and realtime budgets.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "fx.definitions",
                    title: "Definitions",
                    metrics: [
                        metric("fx.definition.count", "Definitions", definitions.count),
                        metric("fx.billboard.count", "Billboards", billboardCount),
                        metric("fx.decal.count", "Decals", decalCount),
                        metric("fx.blend.modes", "Blend modes", FXBlendMode.allCases.count),
                    ]
                ),
                ToolPreviewSection(
                    id: "fx.budget",
                    title: "Realtime budget",
                    metrics: [
                        metric("fx.budget.events", "Events/frame", budget.maxEventsPerFrame),
                        metric("fx.budget.particles", "Particles/frame", budget.maxParticlesPerFrame),
                        metric("fx.budget.decals", "Decals/frame", budget.maxDecalsPerFrame),
                        metric("fx.budget.burst", "Particles/burst", budget.maxParticlesPerBurst),
                    ]
                ),
            ]
        )
    }

    private func audioReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let resolver = AudioRecipeResolver()
        let recipes = resolver.recipes
        let mixState = AudioMixState()
        let locomotionCount = recipes.filter { $0.category == .locomotion }.count
        let noiseSynthCount = recipes.filter { $0.renderer == .noiseSynth }.count
        let hybridCount = recipes.filter { $0.renderer == .hybrid }.count

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Audio Graph Preview",
            summary: "Procedural audio recipes, buses, renderers and default mix routing.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "audio.recipes",
                    title: "Recipes",
                    metrics: [
                        metric("audio.recipe.count", "Recipes", recipes.count),
                        metric("audio.locomotion.count", "Locomotion", locomotionCount),
                        metric("audio.noise-synth.count", "Noise synth", noiseSynthCount),
                        metric("audio.hybrid.count", "Hybrid", hybridCount),
                    ]
                ),
                ToolPreviewSection(
                    id: "audio.mix",
                    title: "Mix",
                    metrics: [
                        metric("audio.bus.count", "Buses", mixState.buses.count),
                        metric("audio.master.gain", "Master gain", decimal(mixState.effectiveGain(for: .master))),
                        metric("audio.foley.gain", "Foley gain", decimal(mixState.effectiveGain(for: .foley))),
                    ]
                ),
            ]
        )
    }

    private func rpgReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let dna = WorldRPGDNA.make(worldSeed: context.worldSeed)
        let ruleset = WorldRuleset.make(worldSeed: context.worldSeed, dna: dna)

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "RPG World DNA",
            summary: "World laws, factions, objectives, quests and enabled RPG systems.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "rpg.dna",
                    title: "DNA",
                    metrics: [
                        metric("rpg.archetype", "Archetype", dna.archetype.displayName),
                        metric("rpg.era", "Era", dna.era.rawValue),
                        metric("rpg.magic", "Magic", dna.magic.rawValue),
                        metric("rpg.threat", "Threat", dna.threat.rawValue),
                    ]
                ),
                ToolPreviewSection(
                    id: "rpg.ruleset",
                    title: "Ruleset",
                    metrics: [
                        metric("rpg.enabled-systems", "Systems", ruleset.enabledSystems.count),
                        metric("rpg.factions", "Factions", ruleset.factions.count),
                        metric("rpg.quests", "Quest seeds", ruleset.questSeeds.count),
                        metric("rpg.playable", "Playable", yesNo(ruleset.validationReport.isPlayable)),
                    ]
                ),
            ]
        )
    }

    private func settlementReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let dna = WorldRPGDNA.make(worldSeed: context.worldSeed)
        let ruleset = WorldRuleset.make(worldSeed: context.worldSeed, dna: dna)
        let biomeType = BiomeType.grassland
        let recipe = SettlementRecipe.makeV1(
            worldSeed: context.worldSeed,
            ruleset: ruleset,
            biomeType: biomeType
        )
        let totalStructureWeight = recipe.buildingDistribution.reduce(Float(0)) { $0 + $1.weight }

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Settlement Viewer",
            summary: "Settlement recipe, support rules and RPG-driven building distribution.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "settlement.recipe",
                    title: "Recipe",
                    metrics: [
                        metric("settlement.type", "Type", recipe.type.rawValue),
                        metric("settlement.biome", "Preview biome", biomeType.rawValue),
                        metric("settlement.buildings", "Desired buildings", recipe.desiredBuildingCount),
                        metric("settlement.radius", "Radius", decimal(recipe.radius)),
                    ]
                ),
                ToolPreviewSection(
                    id: "settlement.rules",
                    title: "Rules",
                    metrics: [
                        metric("settlement.supports", "Support modes", recipe.allowedSupportSolutions.count),
                        metric("settlement.structures", "Structure recipes", recipe.buildingDistribution.count),
                        metric("settlement.structure-weight", "Structure weight", decimal(totalStructureWeight)),
                        metric("settlement.path", "Path kind", recipe.pathKind.rawValue),
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

    private func performanceReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let livePolicy = DebugWorldRunMode.liveGameplay.cadencePolicy
        let slowPolicy = DebugWorldRunMode.slowInspection.cadencePolicy
        let lodPolicy = LODPolicy.chunkBaseline(chunkWorldExtent: 16)
        let fxBudget = FXBudget.v1Realtime
        let renderDebug = RenderDebugOptions()

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Performance HUD",
            summary: "Frame cadence, telemetry throttling and V2 budget contracts.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "performance.cadence",
                    title: "Cadence",
                    metrics: [
                        metric("performance.live.mode", "Live mode", livePolicy.displayName),
                        metric("performance.live.max-fps", "Live max FPS", livePolicy.maxFPS),
                        metric("performance.slow.max-fps", "Slow max FPS", slowPolicy.maxFPS),
                        metric("performance.metrics.hz", "Metrics interval", decimal(Float(DebugWorldRunMode.liveGameplay.metricsRefreshInterval))),
                    ]
                ),
                ToolPreviewSection(
                    id: "performance.budgets",
                    title: "Budgets",
                    metrics: [
                        metric("performance.visible-chunks", "Visible chunks", lodPolicy.budget.maxVisibleChunks),
                        metric("performance.terrain-draws", "Terrain draws", lodPolicy.budget.maxTerrainDrawCalls),
                        metric("performance.fx-particles", "FX particles", fxBudget.maxParticlesPerFrame),
                        metric("performance.debug-bounds-default", "Chunk bounds", yesNo(renderDebug.showChunkBounds)),
                    ]
                ),
            ]
        )
    }

    private func seedGalleryReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let namedSeeds = GoldenWorldSeeds.named
        let seedMatch = namedSeeds.first { $0.seed == context.worldSeed }
        let validation = ToolGoldenSeedValidationRunner().validate()
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
                ToolPreviewSection(
                    id: "seed.validation",
                    title: "Golden validation",
                    metrics: [
                        metric("seed.validation.domains", "Domains", validation.checkedDomainCount),
                        metric("seed.validation.checked", "Checked seeds", validation.checkedSeedCount),
                        metric("seed.validation.issues", "Issues", validation.issueCount),
                        metric("seed.validation.valid", "Valid", yesNo(validation.isValid)),
                    ]
                ),
            ]
        )
    }

    private func snapshotDiffReport(_ context: ToolPreviewReportContext) -> ToolSpecializedPreviewReport {
        let preview = context.registry.makePreviewSnapshot(
            for: context.descriptor,
            document: context.document
        )
        let retention = SnapshotRetentionPolicy()
        let snapshotStore = SnapshotStore(slotID: SaveSlotID("tools-\(context.document.toolID)"))

        return ToolSpecializedPreviewReport(
            toolID: context.descriptor.id,
            title: "Snapshot Diff",
            summary: "Revision snapshots, preview IDs and retention policy contracts.",
            isSpecialized: true,
            sections: [
                ToolPreviewSection(
                    id: "snapshot.preview",
                    title: "Preview",
                    metrics: [
                        metric("snapshot.preview.id", "Preview ID", preview.id.description),
                        metric("snapshot.preview.status", "Status", preview.status.rawValue),
                        metric("snapshot.revision", "Revision", context.document.revisionID),
                        metric("snapshot.references", "References", context.document.packageReferences.count),
                    ]
                ),
                ToolPreviewSection(
                    id: "snapshot.retention",
                    title: "Retention",
                    metrics: [
                        metric("snapshot.reason.count", "Reasons", SnapshotReason.allCases.count),
                        metric("snapshot.store.count", "Stored", snapshotStore.snapshots.count),
                        metric("snapshot.manual.limit", "Manual limit", retention.manualLimit),
                        metric("snapshot.autosave.limit", "Autosave limit", retention.autosaveLimit),
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
