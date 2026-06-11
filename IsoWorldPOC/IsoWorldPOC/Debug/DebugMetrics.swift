//
//  DebugMetrics.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import Combine
import EngineCore
import simd

struct DebugTelemetry: Equatable {
    var framesPerSecond: Float = 0
    var frameTimeMilliseconds: Float = 0
    var renderedFrameCount = 0
    var simulationUpdateMs: Float = 0
    var snapshotBuildMs: Float = 0
    var rawFrameIntervalMs: Float = 0
    var drawTotalMs: Float = 0
    var frameSchedulingGapMs: Float = 0
    var debugMetricsPublishMs: Float = 0
    var unaccountedDrawMs: Float = 0
    var bufferSyncMs: Float = 0
    var renderEncodeMs: Float = 0
    var snapshotActiveChunkDataMs: Float = 0
    var snapshotRenderChunksMs: Float = 0
    var snapshotRenderPropsMs: Float = 0
    var snapshotTerrainSamplePropsMs: Float = 0
    var snapshotChunkCount = 0
    var snapshotPropCount = 0
    var inputState = PlayerInputState()
    var controllerName = "None"
    var playerPosition = SIMD3<Float>(0, 0, 0)
    var terrainHeightUnderPlayer: Float?
    var slopeUnderPlayer: Float?
    var playerGrounded = false
    var maxWalkableSlope: Float = 0
    var currentChunk = ChunkCoordinate.origin
    var currentGroundChunk: ChunkCoordinate?
    var activeChunkCount = 0
    var visibleChunkCount = 0
    var lodCandidateChunkCount = 0
    var lodCulledChunkCount = 0
    var lod0ChunkCount = 0
    var lod1ChunkCount = 0
    var lod2ChunkCount = 0
    var lod3ChunkCount = 0
    var generatedChunkCount = 0
    var cachedChunkCount = 0
    var approximateTriangleCount = 0
    var approximatePropCount = 0
    var chunkJobsQueued = 0
    var chunkJobsGenerating = 0
    var chunksReadyForUpload = 0
    var chunkUploadsThisFrame = 0
    var averageChunkDataGenerationMs: Float?
    var averageChunkUploadMs: Float?
    var metalDrawCallCount = 0
    var metalTerrainDrawCallCount = 0
    var metalPropDrawCallCount = 0
    var metalPlayerDrawCallCount = 0
    var metalDebugDrawCallCount = 0
    var metalFrameGraphPassCount = 0
    var metalFrameGraphEnabledPassCount = 0
    var metalBufferCount = 0
    var metalRenderedChunkCount = 0
    var metalRenderedPropCount = 0
    var metalVisibleTerrainMaterialCount = 0
    var metalVisiblePropMaterialCount = 0
    var metalTerrainTextureLayerCount = 0
    var metalTerrainTextureArrayCount = 0
    var metalVisibleTerrainIndexCount = 0
    var metalVisiblePropIndexCount = 0
    var estimatedChunkCPUBytes = 0
    var estimatedGPUBufferBytes = 0
    var cameraYaw: Float = 0
    var cameraPitch: Float = 0
    var cameraDistance: Float = 0
    var movementMode = "cameraRelative"
    var sunDirection = SIMD3<Float>(0, -1, 0)
    var sunIntensity: Float = 0
    var ambientIntensity: Float = 0
    var shadowsEnabled = false
    var rendererMode = RendererMode.activeMode
}

@MainActor
final class DebugTelemetryStore: ObservableObject {
    @Published private(set) var telemetry = DebugTelemetry()

    func publish(_ nextTelemetry: DebugTelemetry) {
        guard telemetry != nextTelemetry else {
            return
        }

        telemetry = nextTelemetry
    }
}

@MainActor
final class DebugMetrics: ObservableObject {
    let telemetryStore = DebugTelemetryStore()
    @Published var debugWorldRunMode: DebugWorldRunMode
    @Published var showChunkBounds: Bool
    @Published var renderTerrain: Bool
    @Published var renderProps: Bool
    @Published var renderPlayer: Bool
    @Published var freezeSimulation: Bool
    @Published var freezeChunkStreaming: Bool
    @Published var forcedLODLevel: LODLevel?
    @Published var pauseDebugMetricPublishing: Bool
    @Published var terrainMaterialDebugMode: TerrainMaterialDebugMode = .normal
    @Published var terrainSplatDebugLayerIndex = 0

    var framesPerSecond: Float = 0
    var frameTimeMilliseconds: Float = 0
    var renderedFrameCount = 0
    var simulationUpdateMs: Float = 0
    var snapshotBuildMs: Float = 0
    var rawFrameIntervalMs: Float = 0
    var drawTotalMs: Float = 0
    var frameSchedulingGapMs: Float = 0
    var debugMetricsPublishMs: Float = 0
    var unaccountedDrawMs: Float = 0
    var bufferSyncMs: Float = 0
    var renderEncodeMs: Float = 0
    var snapshotActiveChunkDataMs: Float = 0
    var snapshotRenderChunksMs: Float = 0
    var snapshotRenderPropsMs: Float = 0
    var snapshotTerrainSamplePropsMs: Float = 0
    var snapshotChunkCount = 0
    var snapshotPropCount = 0
    var inputState = PlayerInputState()
    var controllerName = "None"
    var playerPosition = SIMD3<Float>(0, 0, 0)
    var terrainHeightUnderPlayer: Float?
    var slopeUnderPlayer: Float?
    var playerGrounded = false
    var maxWalkableSlope: Float = 0
    var currentChunk = ChunkCoordinate.origin
    var currentGroundChunk: ChunkCoordinate?
    var activeChunkCount = 0
    var visibleChunkCount = 0
    var lodCandidateChunkCount = 0
    var lodCulledChunkCount = 0
    var lod0ChunkCount = 0
    var lod1ChunkCount = 0
    var lod2ChunkCount = 0
    var lod3ChunkCount = 0
    var generatedChunkCount = 0
    var cachedChunkCount = 0
    var approximateTriangleCount = 0
    var approximatePropCount = 0
    var chunkJobsQueued = 0
    var chunkJobsGenerating = 0
    var chunksReadyForUpload = 0
    var chunkUploadsThisFrame = 0
    var averageChunkDataGenerationMs: Float?
    var averageChunkUploadMs: Float?
    var metalDrawCallCount = 0
    var metalTerrainDrawCallCount = 0
    var metalPropDrawCallCount = 0
    var metalPlayerDrawCallCount = 0
    var metalDebugDrawCallCount = 0
    var metalFrameGraphPassCount = 0
    var metalFrameGraphEnabledPassCount = 0
    var metalBufferCount = 0
    var metalRenderedChunkCount = 0
    var metalRenderedPropCount = 0
    var metalVisibleTerrainMaterialCount = 0
    var metalVisiblePropMaterialCount = 0
    var metalTerrainTextureLayerCount = 0
    var metalTerrainTextureArrayCount = 0
    var metalVisibleTerrainIndexCount = 0
    var metalVisiblePropIndexCount = 0
    var estimatedChunkCPUBytes = 0
    var estimatedGPUBufferBytes = 0
    var cameraYaw: Float = 0
    var cameraPitch: Float = 0
    var cameraDistance: Float = 0
    var movementMode = "cameraRelative"
    var sunDirection = SIMD3<Float>(0, -1, 0)
    var sunIntensity: Float = 0
    var ambientIntensity: Float = 0
    var shadowsEnabled = false
    var rendererMode = RendererMode.activeMode

    init(
        debugWorldRunMode: DebugWorldRunMode = .slowInspection,
        showChunkBounds: Bool = true,
        renderTerrain: Bool = true,
        renderProps: Bool = true,
        renderPlayer: Bool = true,
        freezeSimulation: Bool = false,
        freezeChunkStreaming: Bool = false,
        forcedLODLevel: LODLevel? = nil,
        pauseDebugMetricPublishing: Bool = false
    ) {
        self.debugWorldRunMode = debugWorldRunMode
        self.showChunkBounds = showChunkBounds
        self.renderTerrain = renderTerrain
        self.renderProps = renderProps
        self.renderPlayer = renderPlayer
        self.freezeSimulation = freezeSimulation
        self.freezeChunkStreaming = freezeChunkStreaming
        self.forcedLODLevel = forcedLODLevel
        self.pauseDebugMetricPublishing = pauseDebugMetricPublishing
    }

    var renderCadenceDescription: String {
        debugWorldRunMode.cadencePolicy.displayName
    }

    var renderCadenceMaxFPS: Int {
        debugWorldRunMode.cadencePolicy.maxFPS
    }

    var renderOnlyWhenDirty: Bool {
        debugWorldRunMode.cadencePolicy.renderOnlyWhenDirty
    }

    var continuousAnimationAllowed: Bool {
        debugWorldRunMode.cadencePolicy.allowContinuousAnimation
    }

    var debugMetricsRefreshFPS: Float {
        Float(1 / debugWorldRunMode.metricsRefreshInterval)
    }

    func applyFrameTiming(
        framesPerSecond: Float,
        frameTimeMilliseconds: Float,
        rawFrameIntervalMs: Float,
        drawTotalMs: Float,
        frameSchedulingGapMs: Float,
        debugMetricsPublishMs: Float,
        unaccountedDrawMs: Float,
        renderedFrameCount: Int
    ) {
        self.framesPerSecond = framesPerSecond
        self.frameTimeMilliseconds = frameTimeMilliseconds
        self.rawFrameIntervalMs = rawFrameIntervalMs
        self.drawTotalMs = drawTotalMs
        self.frameSchedulingGapMs = frameSchedulingGapMs
        self.debugMetricsPublishMs = debugMetricsPublishMs
        self.unaccountedDrawMs = unaccountedDrawMs
        self.renderedFrameCount = renderedFrameCount
    }

    func applyPipelineTiming(
        simulationUpdateMs: Float,
        snapshotBuildMs: Float,
        bufferSyncMs: Float,
        renderEncodeMs: Float
    ) {
        self.simulationUpdateMs = simulationUpdateMs
        self.snapshotBuildMs = snapshotBuildMs
        self.bufferSyncMs = bufferSyncMs
        self.renderEncodeMs = renderEncodeMs
    }

    func applySnapshotTiming(_ timing: RenderSnapshotBuildTiming) {
        snapshotActiveChunkDataMs = timing.activeChunkDataMs
        snapshotRenderChunksMs = timing.renderChunksMs
        snapshotRenderPropsMs = timing.renderPropsMs
        snapshotTerrainSamplePropsMs = timing.terrainSamplePropsMs
        snapshotChunkCount = timing.chunkCount
        snapshotPropCount = timing.propCount
    }

    func publishTelemetry() {
        telemetryStore.publish(makeTelemetry())
    }

    private func makeTelemetry() -> DebugTelemetry {
        DebugTelemetry(
            framesPerSecond: framesPerSecond,
            frameTimeMilliseconds: frameTimeMilliseconds,
            renderedFrameCount: renderedFrameCount,
            simulationUpdateMs: simulationUpdateMs,
            snapshotBuildMs: snapshotBuildMs,
            rawFrameIntervalMs: rawFrameIntervalMs,
            drawTotalMs: drawTotalMs,
            frameSchedulingGapMs: frameSchedulingGapMs,
            debugMetricsPublishMs: debugMetricsPublishMs,
            unaccountedDrawMs: unaccountedDrawMs,
            bufferSyncMs: bufferSyncMs,
            renderEncodeMs: renderEncodeMs,
            snapshotActiveChunkDataMs: snapshotActiveChunkDataMs,
            snapshotRenderChunksMs: snapshotRenderChunksMs,
            snapshotRenderPropsMs: snapshotRenderPropsMs,
            snapshotTerrainSamplePropsMs: snapshotTerrainSamplePropsMs,
            snapshotChunkCount: snapshotChunkCount,
            snapshotPropCount: snapshotPropCount,
            inputState: inputState,
            controllerName: controllerName,
            playerPosition: playerPosition,
            terrainHeightUnderPlayer: terrainHeightUnderPlayer,
            slopeUnderPlayer: slopeUnderPlayer,
            playerGrounded: playerGrounded,
            maxWalkableSlope: maxWalkableSlope,
            currentChunk: currentChunk,
            currentGroundChunk: currentGroundChunk,
            activeChunkCount: activeChunkCount,
            visibleChunkCount: visibleChunkCount,
            lodCandidateChunkCount: lodCandidateChunkCount,
            lodCulledChunkCount: lodCulledChunkCount,
            lod0ChunkCount: lod0ChunkCount,
            lod1ChunkCount: lod1ChunkCount,
            lod2ChunkCount: lod2ChunkCount,
            lod3ChunkCount: lod3ChunkCount,
            generatedChunkCount: generatedChunkCount,
            cachedChunkCount: cachedChunkCount,
            approximateTriangleCount: approximateTriangleCount,
            approximatePropCount: approximatePropCount,
            chunkJobsQueued: chunkJobsQueued,
            chunkJobsGenerating: chunkJobsGenerating,
            chunksReadyForUpload: chunksReadyForUpload,
            chunkUploadsThisFrame: chunkUploadsThisFrame,
            averageChunkDataGenerationMs: averageChunkDataGenerationMs,
            averageChunkUploadMs: averageChunkUploadMs,
            metalDrawCallCount: metalDrawCallCount,
            metalTerrainDrawCallCount: metalTerrainDrawCallCount,
            metalPropDrawCallCount: metalPropDrawCallCount,
            metalPlayerDrawCallCount: metalPlayerDrawCallCount,
            metalDebugDrawCallCount: metalDebugDrawCallCount,
            metalFrameGraphPassCount: metalFrameGraphPassCount,
            metalFrameGraphEnabledPassCount: metalFrameGraphEnabledPassCount,
            metalBufferCount: metalBufferCount,
            metalRenderedChunkCount: metalRenderedChunkCount,
            metalRenderedPropCount: metalRenderedPropCount,
            metalVisibleTerrainMaterialCount: metalVisibleTerrainMaterialCount,
            metalVisiblePropMaterialCount: metalVisiblePropMaterialCount,
            metalTerrainTextureLayerCount: metalTerrainTextureLayerCount,
            metalTerrainTextureArrayCount: metalTerrainTextureArrayCount,
            metalVisibleTerrainIndexCount: metalVisibleTerrainIndexCount,
            metalVisiblePropIndexCount: metalVisiblePropIndexCount,
            estimatedChunkCPUBytes: estimatedChunkCPUBytes,
            estimatedGPUBufferBytes: estimatedGPUBufferBytes,
            cameraYaw: cameraYaw,
            cameraPitch: cameraPitch,
            cameraDistance: cameraDistance,
            movementMode: movementMode,
            sunDirection: sunDirection,
            sunIntensity: sunIntensity,
            ambientIntensity: ambientIntensity,
            shadowsEnabled: shadowsEnabled,
            rendererMode: rendererMode
        )
    }

    private func assignIfNeeded<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<DebugMetrics, Value>, _ value: Value) {
        guard self[keyPath: keyPath] != value else {
            return
        }

        self[keyPath: keyPath] = value
    }
}
