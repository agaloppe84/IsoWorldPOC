//
//  IsoWorldPOCTests.swift
//  IsoWorldPOCTests
//
//  Created by Work on 09/06/2026.
//

import EngineCore
import Combine
import simd
import Testing
@testable import IsoWorldPOC

struct IsoWorldPOCTests {

    @Test func slowInspectionUsesThrottledCadence() {
        let policy = DebugWorldRunMode.slowInspection.cadencePolicy

        #expect(policy.mode == .throttled(fps: 15))
        #expect(policy.maxFPS == 15)
        #expect(policy.renderOnlyWhenDirty == false)
        #expect(policy.allowContinuousAnimation == true)
        #expect(DebugWorldRunMode.slowInspection.metricsRefreshInterval == 0.50)
    }

    @Test func pausedInspectionRendersOnlyWhenDirty() {
        let policy = DebugWorldRunMode.pausedInspection.cadencePolicy

        #expect(policy.mode == .onDemand)
        #expect(policy.renderOnlyWhenDirty == true)
        #expect(policy.allowContinuousAnimation == false)
    }

    @Test func liveGameplayIsTheOnlyNormalDisplayLinkedMode() {
        let policy = DebugWorldRunMode.liveGameplay.cadencePolicy

        #expect(policy.mode == .displayLinked)
        #expect(policy.maxFPS == 60)
        #expect(policy.renderOnlyWhenDirty == false)
        #expect(policy.allowContinuousAnimation == true)
        #expect(DebugWorldRunMode.liveGameplay.metricsRefreshInterval == 0.50)
    }

    @MainActor
    @Test func realWorldDisablesDebugTelemetryByDefault() {
        let realWorld = GameRootView(
            showsDebugOverlay: false,
            initialRunMode: .liveGameplay
        )
        let debugWorld = GameRootView(
            showsDebugOverlay: true,
            initialRunMode: .slowInspection
        )

        #expect(realWorld.publishesDebugTelemetry == false)
        #expect(debugWorld.publishesDebugTelemetry == true)
    }

    @MainActor
    @Test func liveDebugMetricsProfileStartsCleanButRenderable() {
        let metrics = DebugMetrics(
            debugWorldRunMode: .liveGameplay,
            showChunkBounds: false
        )

        #expect(metrics.debugWorldRunMode == .liveGameplay)
        #expect(metrics.showChunkBounds == false)
        #expect(metrics.renderTerrain)
        #expect(metrics.renderProps)
        #expect(metrics.renderPlayer)
        #expect(metrics.freezeSimulation == false)
        #expect(metrics.freezeChunkStreaming == false)
        #expect(metrics.forcedLODLevel == nil)
        #expect(metrics.pauseDebugMetricPublishing == false)
        #expect(metrics.showDebugDetails == false)
    }

    @MainActor
    @Test func debugMetricsStartWithLeanOverlayDefaults() {
        let metrics = DebugMetrics()

        #expect(metrics.showChunkBounds == false)
        #expect(metrics.showDebugDetails == false)
        #expect(metrics.debugMetricsRefreshFPS == 2)
    }

    @MainActor
    @Test func debugMetricsStoreFrameLoopDiagnostics() {
        let metrics = DebugMetrics()

        metrics.applyFrameTiming(
            framesPerSecond: 30,
            frameTimeMilliseconds: 33.33,
            rawFrameIntervalMs: 45,
            drawTotalMs: 12,
            frameSchedulingGapMs: 33,
            debugMetricsPublishMs: 2,
            unaccountedDrawMs: 1,
            renderedFrameCount: 7
        )
        metrics.publishTelemetry()

        let telemetry = metrics.telemetryStore.telemetry
        #expect(telemetry.framesPerSecond == 30)
        #expect(telemetry.rawFrameIntervalMs == 45)
        #expect(telemetry.drawTotalMs == 12)
        #expect(telemetry.frameSchedulingGapMs == 33)
        #expect(telemetry.debugMetricsPublishMs == 2)
        #expect(telemetry.unaccountedDrawMs == 1)
        #expect(telemetry.renderedFrameCount == 7)
    }

    @MainActor
    @Test func telemetryPublishDoesNotInvalidateDebugMetricsControls() {
        let metrics = DebugMetrics()
        var controlsInvalidationCount = 0
        var telemetryInvalidationCount = 0
        let controlsCancellable = metrics.objectWillChange.sink {
            controlsInvalidationCount += 1
        }
        let telemetryCancellable = metrics.telemetryStore.objectWillChange.sink {
            telemetryInvalidationCount += 1
        }

        metrics.applyFrameTiming(
            framesPerSecond: 30,
            frameTimeMilliseconds: 33.33,
            rawFrameIntervalMs: 45,
            drawTotalMs: 12,
            frameSchedulingGapMs: 33,
            debugMetricsPublishMs: 2,
            unaccountedDrawMs: 1,
            renderedFrameCount: 7
        )
        metrics.publishTelemetry()

        #expect(controlsInvalidationCount == 0)
        #expect(telemetryInvalidationCount == 1)
        _ = controlsCancellable
        _ = telemetryCancellable
    }

    @Test func renderSnapshotDebugOptionsDefaultToDebugInspection() {
        let options = RenderSnapshotDebugOptions.defaults

        #expect(options.showChunkBounds)
        #expect(options.renderTerrain)
        #expect(options.renderProps)
        #expect(options.renderPlayer)
        #expect(options.freezeSimulation == false)
        #expect(options.freezeChunkStreaming == false)
        #expect(options.forcedLODLevel == nil)
    }

    @Test func metalDebugUniformsExposeIsolationLayerFlags() {
        let enabledUniforms = MetalRenderDebugUniforms(
            options: RenderDebugOptions(renderTerrain: true, renderProps: true)
        )
        let disabledUniforms = MetalRenderDebugUniforms(
            options: RenderDebugOptions(renderTerrain: false, renderProps: false)
        )

        #expect(enabledUniforms.terrainMaterialModeAndFlags.z == 1)
        #expect(enabledUniforms.terrainMaterialModeAndFlags.w == 1)
        #expect(disabledUniforms.terrainMaterialModeAndFlags.z == 0)
        #expect(disabledUniforms.terrainMaterialModeAndFlags.w == 0)
    }

    @Test func worldFrameGraphKeepsBaselinePassOrder() {
        let passKinds = FrameGraph.worldRenderer.passDescriptors.map(\.kind)

        #expect(passKinds == [
            .depthPrepass,
            .opaque,
            .debugOverlay,
            .hudOverlay,
        ])
    }

    @MainActor
    @Test func appStoreStartsInMainMenu() {
        let store = AppStore()

        #expect(store.mode == .mainMenu)
        #expect(store.loadingProgress == nil)
        #expect(store.currentWorldSession == nil)
        #expect(store.currentToolSession == nil)
    }

    @MainActor
    @Test func debugWorldTransitionDoesNotStartLoading() {
        let store = AppStore()

        store.openDebugWorld()

        if case .debugWorld = store.mode {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected debug world mode")
        }

        #expect(store.loadingProgress == nil)
        #expect(store.currentWorldSession == nil)
        #expect(store.currentToolSession == nil)
    }

    @MainActor
    @Test func toolsHubTransitionDoesNotCreateWorldSession() {
        let store = AppStore()

        store.openToolsHub()

        if case .toolsHub = store.mode {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected tools hub mode")
        }

        #expect(store.loadingProgress == nil)
        #expect(store.currentWorldSession == nil)
        #expect(store.currentToolSession != nil)
    }

    @Test func toolRegistryExposesStep13V1Tools() {
        let registry = ToolRegistry.v1

        #expect(registry.descriptors.map(\.name) == [
            "Terrain Viewer",
            "Biome Viewer",
            "Prop Gallery",
            "Material Viewer",
            "LOD Debugger",
            "Seed Explorer",
        ])
        #expect(Set(registry.descriptors.map(\.id)) == Set([
            "terrain.viewer",
            "biome.viewer",
            "prop.gallery",
            "material.viewer",
            "lod.debugger",
            "seed.explorer",
        ]))
        #expect(registry.descriptors.allSatisfy { !$0.capabilities.isEmpty })
    }

    @Test func toolRegistryCreatesDeterministicPreviewWithoutWorldPayload() {
        let registry = ToolRegistry.v1
        let descriptor = registry.descriptor(for: "terrain.viewer")!
        let document = ToolDocument(
            toolID: descriptor.id,
            seedText: "step-13-seed",
            presetName: "Terrain baseline",
            sampleCount: 32
        )

        let firstPreview = registry.makePreviewSnapshot(for: descriptor, document: document)
        let secondPreview = registry.makePreviewSnapshot(for: descriptor, document: document)

        #expect(firstPreview == secondPreview)
        #expect(firstPreview.status == .ready)
        #expect(firstPreview.render == nil)
        #expect(firstPreview.worldSeed == registry.worldSeed(from: document.seedText))
    }

    @MainActor
    @Test func prepareWorldNormalizesEmptySeedAndStartsLoading() {
        let store = AppStore(seedInput: "   ")

        store.prepareWorldFromSeed()

        if case .preparingWorld = store.mode {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected preparing world mode")
        }

        #expect(store.loadingProgress?.seed == "isoworld-seed-001")
        #expect(store.currentWorldSession == nil)
        #expect(store.currentToolSession == nil)
    }

    @MainActor
    @Test func worldPreparePipelineBuildsRequiredSessionBeforeOpening() async throws {
        let pipeline = WorldPreparePipeline()
        var updates: [LoadingProgress] = []

        let session = try await pipeline.prepareWorld(
            request: WorldPrepareRequest(seedText: "step-12-test", initialChunkRadius: 1)
        ) { progress in
            updates.append(progress)
        }

        #expect(session.seed == "step-12-test")
        #expect(session.initialChunkCount == 9)
        #expect(session.openRequirements.isSatisfied)
        #expect(session.openRequirements.requiredInitialChunkCount == 9)
        #expect(session.initialChunks.contains { $0.coordinate == .origin })
        #expect(updates.first?.currentPhase == .validateSeed)
        #expect(updates.last?.currentPhase == .openSession)
        #expect(updates.last?.globalProgress == 1)
    }

    @MainActor
    @Test func worldRuntimeStartsFromPreparedWorldSession() async throws {
        let pipeline = WorldPreparePipeline()
        let session = try await pipeline.prepareWorld(
            request: WorldPrepareRequest(seedText: "runtime-prepared-session", initialChunkRadius: 0)
        ) { _ in }

        let runtime = WorldRuntime(worldSession: session)

        #expect(runtime.frameSnapshot.worldSeed == session.worldSeed)
        #expect(runtime.playerPosition.x == session.spawnPosition.x)
        #expect(runtime.playerPosition.z == session.spawnPosition.z)
        #expect(runtime.frameSnapshot.debug.cachedChunkCount >= session.initialChunkCount)
    }

    @MainActor
    @Test func worldRuntimeFreezeSimulationKeepsSimulationClockStable() {
        let runtime = WorldRuntime()
        let initialSimulationTime = runtime.frameSnapshot.simulationTime
        let debugOptions = RenderSnapshotDebugOptions(
            showChunkBounds: false,
            renderTerrain: true,
            renderProps: true,
            renderPlayer: true,
            terrainMaterialDebugMode: .normal,
            terrainSplatDebugLayerIndex: 0,
            freezeSimulation: true,
            freezeChunkStreaming: false,
            forcedLODLevel: nil
        )

        _ = runtime.update(deltaTime: 1.0, debugOptions: debugOptions)

        #expect(runtime.frameSnapshot.simulationTime == initialSimulationTime)
    }

    @MainActor
    @Test func worldRuntimeOmitsPropsFromSnapshotWhenRenderPropsIsDisabled() async throws {
        let pipeline = WorldPreparePipeline()
        let session = try await pipeline.prepareWorld(
            request: WorldPrepareRequest(seedText: "snapshot-props-off", initialChunkRadius: 0)
        ) { _ in }
        let debugOptions = RenderSnapshotDebugOptions(
            showChunkBounds: false,
            renderTerrain: true,
            renderProps: false,
            renderPlayer: true,
            terrainMaterialDebugMode: .normal,
            terrainSplatDebugLayerIndex: 0,
            freezeSimulation: false,
            freezeChunkStreaming: false,
            forcedLODLevel: nil
        )
        let runtime = WorldRuntime(worldSession: session, debugOptions: debugOptions)

        let snapshot = runtime.update(deltaTime: 0, debugOptions: debugOptions)

        #expect(snapshot.debugOptions.renderProps == false)
        #expect(snapshot.chunks.allSatisfy { $0.props.isEmpty })
        #expect(runtime.snapshotBuildTiming.propCount == 0)
    }

    @MainActor
    @Test func worldRuntimeCachesStableRenderChunksBetweenFrames() {
        let runtime = WorldRuntime()
        let debugOptions = RenderSnapshotDebugOptions(
            showChunkBounds: false,
            renderTerrain: true,
            renderProps: true,
            renderPlayer: true,
            terrainMaterialDebugMode: .normal,
            terrainSplatDebugLayerIndex: 0,
            freezeSimulation: true,
            freezeChunkStreaming: true,
            forcedLODLevel: nil
        )

        _ = runtime.update(deltaTime: 0, debugOptions: debugOptions)
        let cachedSnapshot = runtime.update(deltaTime: 0, debugOptions: debugOptions)

        #expect(cachedSnapshot.chunks.allSatisfy { $0.isVisible })
        #expect(cachedSnapshot.chunks.count == cachedSnapshot.visibleChunkCount)
        #expect(runtime.snapshotBuildTiming.renderPropsMs == 0)
        #expect(runtime.snapshotBuildTiming.propCount == cachedSnapshot.visiblePropCount)
    }

    @Test func materialBindingTableKeepsTerrainPBRTextureSlotsStable() {
        let descriptors = TerrainTextureSlot.allTerrainPBRSlots.map { slot in
            TerrainTextureDescriptor(slot: slot, debugColor: SIMD4<Float>.zero)
        }
        let table = MaterialBindingTable(descriptors: descriptors)

        #expect(table.terrainLayerCount == TerrainMaterialKind.allCases.count)
        #expect(table.terrainTextureArrayCount == TerrainTextureMap.allCases.count)
        #expect(
            table.binding(for: .rock)?.textureLayerIndex ==
                TerrainTextureSlot.textureLayerIndex(for: .rock)
        )
        #expect(MaterialBindingTable.terrainAlbedoTextureIndex == 0)
        #expect(MaterialBindingTable.terrainNormalTextureIndex == 1)
        #expect(MaterialBindingTable.terrainRoughnessTextureIndex == 2)
        #expect(MaterialBindingTable.terrainMetallicAmbientOcclusionTextureIndex == 3)
        #expect(MaterialBindingTable.terrainSamplerIndex == 0)
    }

    @Test func metalPropMeshBakesNaturalConeAndCapsuleShapes() {
        let variant = PropVariant(
            placement: PropPlacement(
                placementIndex: 0,
                type: .deadwood,
                localX: 0,
                localZ: 0,
                worldX: 0,
                worldZ: 0,
                rotationRadians: 0,
                scale: 1
            ),
            archetypeID: "test.natural",
            variantSeed: 1,
            size: PropVector3(x: 1, y: 1, z: 1),
            proportions: PropVector3(x: 1, y: 1, z: 1),
            geometry: PropGeometryDescriptor(parts: [
                PropGeometryPart(
                    shape: .capsule,
                    size: PropVector3(x: 0.3, y: 1.0, z: 0.3),
                    position: PropVector3(x: 0, y: 0.5, z: 0),
                    materialSlot: .primary
                ),
                PropGeometryPart(
                    shape: .cone,
                    size: PropVector3(x: 0.4, y: 0.8, z: 0.4),
                    position: PropVector3(x: 0.4, y: 0.4, z: 0),
                    materialSlot: .accent
                ),
            ]),
            primaryMaterial: samplePropMaterial(identifier: "primary"),
            secondaryMaterial: samplePropMaterial(identifier: "secondary"),
            accentMaterial: samplePropMaterial(identifier: "accent"),
            collisionSize: PropVector3(x: 1, y: 1, z: 1)
        )
        let chunk = RenderChunk(
            coordinate: .origin,
            origin: WorldPosition(x: 0, y: 0, z: 0),
            terrainGeometry: sampleTerrainGeometry(),
            biome: Biome.definition(for: .temperateForest),
            terrainMaterial: .definition(for: .grass),
            props: [
                RenderProp(
                    variant: variant,
                    worldPosition: WorldPosition(x: 0, y: 0, z: 0),
                    rotationRadians: 0
                )
            ],
            approximateTriangleCount: 2
        )
        let mesh = MetalChunkBuffers.propMesh(for: chunk)

        #expect(mesh.vertices.count > 24)
        #expect(mesh.indices.count > 36)
        #expect(mesh.indices.count.isMultiple(of: 3))
    }

    private func samplePropMaterial(identifier: String) -> PropMaterialDescriptor {
        PropMaterialDescriptor(
            identifier: identifier,
            color: BiomeColor(red: 0.4, green: 0.5, blue: 0.3),
            roughness: 0.8
        )
    }

    private func sampleTerrainGeometry() -> TerrainGeometryBuffers {
        ChunkCoordinate.origin.makeTerrainGeometry(
            seed: WorldSeed(1),
            horizontalScale: 1,
            verticalScale: 1
        )
    }

}
