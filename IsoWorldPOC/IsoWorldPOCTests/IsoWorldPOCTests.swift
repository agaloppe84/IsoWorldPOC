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
            .decals,
            .billboardParticles,
            .debugOverlay,
            .hudOverlay,
        ])
    }

    @Test func worldFrameGraphEnablesFXPassesOnlyFromSnapshotFX() {
        let emptyPlan = FrameGraph.worldRenderer.makePlan(for: frameContext(fx: .empty))
        let fxPlan = FrameGraph.worldRenderer.makePlan(for: frameContext(fx: sampleFXSnapshot()))

        #expect(emptyPlan.passes.first { $0.descriptor.kind == .decals }?.isEnabled == false)
        #expect(emptyPlan.passes.first { $0.descriptor.kind == .billboardParticles }?.isEnabled == false)
        #expect(fxPlan.passes.first { $0.descriptor.kind == .decals }?.isEnabled == true)
        #expect(fxPlan.passes.first { $0.descriptor.kind == .billboardParticles }?.isEnabled == true)
    }

    @Test func worldFrameGraphEnablesHUDPassOnlyFromVisibleUISnapshot() {
        let hiddenPlan = FrameGraph.worldRenderer.makePlan(
            for: frameContext(fx: .empty, ui: .empty)
        )
        let visiblePlan = FrameGraph.worldRenderer.makePlan(
            for: frameContext(fx: .empty, ui: sampleUIFrameSnapshot())
        )

        #expect(hiddenPlan.passes.first { $0.descriptor.kind == .hudOverlay }?.isEnabled == false)
        #expect(visiblePlan.passes.first { $0.descriptor.kind == .hudOverlay }?.isEnabled == true)
    }

    @Test func uiMetalRendererBuildsBatchedHUDCommands() {
        let renderer = UIMetalRenderer(device: nil)
        let commands = renderer.makeDrawCommands(
            snapshot: sampleUIFrameSnapshot(),
            drawableSize: SIMD2<Float>(1_280, 720)
        )

        #expect(commands.contains { $0.kind == .panel })
        #expect(commands.contains { $0.kind == .fill })
        #expect(commands.contains { $0.kind == .icon })
        #expect(commands.contains { $0.kind == .glyph })
        #expect(commands == UIDrawCommandBatcher.sorted(commands))
    }

    @Test func uiMetalRendererHUDVertexPayloadExceedsInlineMetalLimit() {
        let renderer = UIMetalRenderer(device: nil)
        let commands = renderer.makeDrawCommands(
            snapshot: sampleUIFrameSnapshot(),
            drawableSize: SIMD2<Float>(1_280, 720)
        )
        let vertices = renderer.makeVertices(for: commands)
        let byteCount = UIMetalRenderer.vertexByteCount(vertexCount: vertices.count)

        #expect(vertices.count == commands.count * 6)
        #expect(byteCount > UIMetalRenderer.maxInlineVertexBytes)
    }

    @Test func audioEventQueuePrioritizesAndDropsOverCapacity() {
        let queue = AudioEventQueue(capacity: 2)

        queue.enqueue(sampleAudioEvent(id: 1, priority: .ambience))
        queue.enqueue(sampleAudioEvent(id: 2, priority: .critical))
        queue.enqueue(sampleAudioEvent(id: 3, priority: .gameplay))

        let drained = queue.drain()

        #expect(queue.droppedEventCount == 1)
        #expect(drained.map(\.id.rawValue) == [2, 3])
    }

    @Test func noiseSynthIsDeterministicForSameSeededEvent() {
        let recipe = AudioRecipe.footstep(for: .sand)
        let event = sampleAudioEvent(
            id: 10,
            recipeID: recipe.id,
            bus: recipe.bus,
            parameters: recipe.defaultParameters
                .setting(.gain, to: 0.7)
                .setting(.durationSeconds, to: 0.08)
        )
        let synth = NoiseSynth(sampleRate: 8_000)

        let first = synth.render(event: event, recipe: recipe)
        let second = synth.render(event: event, recipe: recipe)

        #expect(first == second)
        #expect(first.peak > 0)
        #expect(abs(first.durationSeconds - 0.08) < 0.0001)
    }

    @Test func isoAudioEngineProcessesFootstepEventIntoFoleyMeter() {
        let recipe = AudioRecipe.footstep(for: .rock)
        let engine = IsoAudioEngine(
            recipes: [recipe],
            eventQueue: AudioEventQueue(capacity: 4),
            samplePlayer: SamplePlayer(sampleRate: 8_000),
            noiseSynth: NoiseSynth(sampleRate: 8_000)
        )
        let event = sampleAudioEvent(
            recipeID: recipe.id,
            bus: recipe.bus,
            parameters: recipe.defaultParameters
                .setting(.gain, to: 0.8)
                .setting(.durationSeconds, to: 0.05)
        )

        engine.post(event)
        let snapshot = engine.update()
        let foleyMeter = snapshot.busMeters.first { $0.bus == .foley }

        #expect(snapshot.processedEventCount == 1)
        #expect(snapshot.totalProcessedEventCount == 1)
        #expect(snapshot.activeVoiceCount == 1)
        #expect(snapshot.peak > 0)
        #expect(foleyMeter?.processedEventCount == 1)
        #expect(foleyMeter?.activeVoiceCount == 1)
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
    @Test func worldRuntimePublishesUIFrameSnapshotFromPreparedSession() async throws {
        let pipeline = WorldPreparePipeline()
        let session = try await pipeline.prepareWorld(
            request: WorldPrepareRequest(seedText: "runtime-ui-session", initialChunkRadius: 0)
        ) { _ in }

        let runtime = WorldRuntime(worldSession: session)
        let snapshot = runtime.uiFrameSnapshot

        #expect(snapshot.worldSeed == session.worldSeed)
        #expect(snapshot.hasVisibleHUD)
        #expect(UIThemeID.allCases.contains(snapshot.theme.id))
        #expect(snapshot.hud.player.health == 1)
        #expect(snapshot.hud.player.stamina == 1)
        #expect(snapshot.hud.biome.displayName.isEmpty == false)
    }

    @MainActor
    @Test func worldRuntimeCreatesPlayerCharacterFromPreparedWorldSeed() async throws {
        let pipeline = WorldPreparePipeline()
        let session = try await pipeline.prepareWorld(
            request: WorldPrepareRequest(seedText: "runtime-character-session", initialChunkRadius: 0)
        ) { _ in }

        let runtime = WorldRuntime(worldSession: session)
        let expectedDNA = CharacterDNA.makePlayer(worldSeed: session.worldSeed)

        #expect(runtime.playerCharacterDNA == expectedDNA)
        #expect(runtime.playerCharacterDNA.body.collisionCapsule.height > 0)
    }

    @MainActor
    @Test func worldRuntimeUpdatesPlayerAnimationContactsFromPreparedTerrain() async throws {
        let pipeline = WorldPreparePipeline()
        let session = try await pipeline.prepareWorld(
            request: WorldPrepareRequest(seedText: "runtime-animation-session", initialChunkRadius: 2)
        ) { _ in }
        let spawnCoordinate = ChunkCoordinate(
            x: Int(((session.spawnPosition.x + ProceduralChunkDataFactory.chunkWorldSize * 0.5) /
                ProceduralChunkDataFactory.chunkWorldSize).rounded(.down)),
            y: 0,
            z: Int(((session.spawnPosition.z + ProceduralChunkDataFactory.chunkWorldSize * 0.5) /
                ProceduralChunkDataFactory.chunkWorldSize).rounded(.down))
        )
        let spawnChunk = try #require(session.initialChunks.first { $0.coordinate == spawnCoordinate })
        let sampler = TerrainSampler(
            geometry: spawnChunk.terrainGeometry,
            originX: spawnChunk.originX,
            originZ: spawnChunk.originZ
        )
        let localX = (session.spawnPosition.x - spawnChunk.originX) /
            ProceduralChunkDataFactory.horizontalScale
        let localZ = (session.spawnPosition.z - spawnChunk.originZ) /
            ProceduralChunkDataFactory.horizontalScale
        let terrainSample = spawnChunk.terrainSampleGrid.sample(
            localX: min(max(Int(localX.rounded()), 0), ProceduralChunkDataFactory.chunkResolution - 1),
            localZ: min(max(Int(localZ.rounded()), 0), ProceduralChunkDataFactory.chunkResolution - 1)
        )
        let groundSample = TerrainGroundSample(
            sample: sampler.sampleAt(x: session.spawnPosition.x, z: session.spawnPosition.z),
            terrainSample: terrainSample,
            surfaceClass: spawnChunk.traversalData.surfaceClass(nearestLocalX: localX, nearestLocalZ: localZ),
            chunk: spawnChunk.coordinate
        )
        let contactPatch = groundSample.contactPatch(
            worldX: session.spawnPosition.x,
            worldZ: session.spawnPosition.z
        )
        let runtime = WorldRuntime(worldSession: session)

        _ = runtime.update(deltaTime: 1.0 / 60.0, debugOptions: .defaults)

        #expect(contactPatch?.isUsableFootSupport == true)
        #expect(AnimationClipID.allCases.contains(runtime.playerAnimationSample.clipID))
        #expect(runtime.playerAnimationSample.pose.joint(.leftFoot) != nil)
        #expect(runtime.playerAnimationSample.pose.joint(.rightFoot) != nil)
        #expect(runtime.playerFootIKResults.count == AnimationFootSide.allCases.count)
        #expect(runtime.playerFootIKResults.values.allSatisfy { $0.target.y.isFinite })
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

    @Test func playerGroundingUsesTraversalSurfaceClassWhenAvailable() {
        let grounding = PlayerGrounding()
        let previousGround = TerrainGroundSample(
            sample: TerrainSampler.Sample(height: 0, slope: 0),
            surfaceClass: .walkable,
            chunk: .origin
        )
        let blockedGround = TerrainGroundSample(
            sample: TerrainSampler.Sample(height: 1, slope: 0),
            surfaceClass: .blocked,
            chunk: .origin
        )
        let result = grounding.resolve(
            previousPosition: SIMD3<Float>(0, 0, 0),
            proposedPosition: SIMD3<Float>(1, 0, 0),
            proposedGround: blockedGround,
            previousGround: previousGround
        )

        #expect(result.position.x == 0)
        #expect(result.playerGrounded)
        #expect(result.movementBlockedBySlope)
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

    private func sampleAudioEvent(
        id: UInt64 = 1,
        recipeID: AudioRecipeID = .footstep(for: .rock),
        bus: AudioBusID = .foley,
        priority: AudioPriority = .gameplay,
        parameters: AudioParameterSet = AudioRecipe.footstep(for: .rock).defaultParameters
            .setting(.gain, to: 0.6)
            .setting(.durationSeconds, to: 0.08)
    ) -> IsoAudioEvent {
        IsoAudioEvent(
            id: StableID(id),
            sourceID: StableID(id + 1_000),
            kind: .footstep,
            recipeID: recipeID,
            bus: bus,
            time: 0.1,
            priority: priority,
            position: WorldPosition(x: 1, y: 0, z: 2),
            surface: AudioSurfaceResponse.response(
                for: .rock,
                wetness: 0,
                friction: 0.7
            ).surfaceInfo(wetness: 0, friction: 0.7),
            seedContext: AudioSeedContext(
                worldSeed: WorldSeed(42),
                eventSeed: 10_000 + id
            ),
            parameters: parameters
        )
    }

    private func frameContext(
        fx: FXFrameSnapshot,
        ui: UIFrameSnapshot = .empty
    ) -> MetalFrameContext {
        MetalFrameContext(
            snapshot: RenderWorldSnapshot(
                camera: CameraRenderState(
                    position: WorldPosition(x: 0, y: 2, z: 4),
                    target: WorldPosition(x: 0, y: 0, z: 0),
                    fieldOfViewDegrees: 35,
                    yaw: 0,
                    pitch: -0.3,
                    distance: 4
                ),
                chunks: [],
                debugOptions: RenderDebugOptions(showChunkBounds: false),
                fx: fx,
                ui: ui
            ),
            chunkBuffersByCoordinate: [:],
            playerBuffers: nil,
            playerPosition: .zero,
            viewProjectionMatrix: matrix_identity_float4x4,
            drawableSize: SIMD2<Float>(1_280, 720)
        )
    }

    private func sampleUIFrameSnapshot() -> UIFrameSnapshot {
        let worldSeed = WorldSeed(42)
        let biome = Biome.definition(for: .temperateForest)
        let dna = UIWorldDNA(
            seed: 42,
            themeID: .neutral,
            informationDensity: .standard,
            diegeticLevel: .nonDiegetic,
            materialLanguage: .neutralGlass,
            shapeLanguage: .softRect,
            biomeReactivity: 0.4,
            motionIntensity: 0.2,
            legibilityBias: 0.9
        )

        return UIFrameSnapshot.make(
            worldSeed: worldSeed,
            simulationTime: 1,
            dna: dna,
            player: PlayerHUDState(
                health: 0.75,
                stamina: 0.5,
                fatigue: 0.1,
                wetness: 0,
                movementStance: .standing
            ),
            biome: biome,
            weather: WeatherHUDState(kind: .clear, severity: 0, label: "Clear"),
            terrainPrompt: "SLOPE"
        )
    }

    private func sampleFXSnapshot() -> FXFrameSnapshot {
        let particle = FXBillboardParticle(
            id: StableID(1),
            definitionID: .footstepDust,
            materialKind: .dirt,
            position: SIMD3<Float>(0, 0.1, 0),
            velocity: .zero,
            startColor: FXColor(red: 1, green: 1, blue: 1, alpha: 0.5),
            endColor: FXColor(red: 1, green: 1, blue: 1, alpha: 0),
            startSize: 0.1,
            endSize: 0.2,
            lifetime: 0.5,
            gravity: 0,
            seed: 1
        )
        let decal = FXDecal(
            id: StableID(2),
            definitionID: .footprintDecal,
            materialKind: .dirt,
            position: .zero,
            color: FXColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.3),
            radius: 0.2,
            opacity: 0.5,
            rotationRadians: 0,
            lifetime: 2,
            seed: 2
        )

        return FXFrameSnapshot(
            events: [],
            particles: [particle],
            decals: [decal],
            budget: FXBudgetResult(
                eventCount: 0,
                particleCount: 1,
                decalCount: 1,
                droppedEvents: 0,
                droppedParticles: 0,
                droppedDecals: 0
            )
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
