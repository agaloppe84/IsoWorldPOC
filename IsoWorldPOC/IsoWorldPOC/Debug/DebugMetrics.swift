//
//  DebugMetrics.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import Combine
import EngineCore
import simd

@MainActor
final class DebugMetrics: ObservableObject {
    @Published var framesPerSecond: Float = 0
    @Published var frameTimeMilliseconds: Float = 0
    @Published var debugWorldRunMode: DebugWorldRunMode
    @Published var renderedFrameCount = 0
    @Published var simulationUpdateMs: Float = 0
    @Published var snapshotBuildMs: Float = 0
    @Published var bufferSyncMs: Float = 0
    @Published var renderEncodeMs: Float = 0
    @Published var inputState = PlayerInputState()
    @Published var controllerName = "None"
    @Published var playerPosition = SIMD3<Float>(0, 0, 0)
    @Published var terrainHeightUnderPlayer: Float?
    @Published var slopeUnderPlayer: Float?
    @Published var playerGrounded = false
    @Published var maxWalkableSlope: Float = 0
    @Published var currentChunk = ChunkCoordinate.origin
    @Published var currentGroundChunk: ChunkCoordinate?
    @Published var activeChunkCount = 0
    @Published var visibleChunkCount = 0
    @Published var lodCandidateChunkCount = 0
    @Published var lodCulledChunkCount = 0
    @Published var lod0ChunkCount = 0
    @Published var lod1ChunkCount = 0
    @Published var lod2ChunkCount = 0
    @Published var lod3ChunkCount = 0
    @Published var generatedChunkCount = 0
    @Published var cachedChunkCount = 0
    @Published var approximateTriangleCount = 0
    @Published var approximatePropCount = 0
    @Published var chunkJobsQueued = 0
    @Published var chunkJobsGenerating = 0
    @Published var chunksReadyForUpload = 0
    @Published var chunkUploadsThisFrame = 0
    @Published var averageChunkDataGenerationMs: Float?
    @Published var averageChunkUploadMs: Float?
    @Published var metalDrawCallCount = 0
    @Published var metalTerrainDrawCallCount = 0
    @Published var metalPropDrawCallCount = 0
    @Published var metalPlayerDrawCallCount = 0
    @Published var metalDebugDrawCallCount = 0
    @Published var metalFrameGraphPassCount = 0
    @Published var metalFrameGraphEnabledPassCount = 0
    @Published var metalBufferCount = 0
    @Published var metalRenderedChunkCount = 0
    @Published var metalRenderedPropCount = 0
    @Published var metalVisibleTerrainMaterialCount = 0
    @Published var metalVisiblePropMaterialCount = 0
    @Published var metalTerrainTextureLayerCount = 0
    @Published var metalTerrainTextureArrayCount = 0
    @Published var metalVisibleTerrainIndexCount = 0
    @Published var metalVisiblePropIndexCount = 0
    @Published var estimatedChunkCPUBytes = 0
    @Published var estimatedGPUBufferBytes = 0
    @Published var showChunkBounds: Bool
    @Published var renderTerrain: Bool
    @Published var renderProps: Bool
    @Published var renderPlayer: Bool
    @Published var freezeSimulation: Bool
    @Published var freezeChunkStreaming: Bool
    @Published var forcedLODLevel: LODLevel?
    @Published var cameraYaw: Float = 0
    @Published var cameraPitch: Float = 0
    @Published var cameraDistance: Float = 0
    @Published var movementMode = "cameraRelative"
    @Published var sunDirection = SIMD3<Float>(0, -1, 0)
    @Published var sunIntensity: Float = 0
    @Published var ambientIntensity: Float = 0
    @Published var shadowsEnabled = false
    @Published var terrainMaterialDebugMode: TerrainMaterialDebugMode = .normal
    @Published var terrainSplatDebugLayerIndex = 0
    @Published var rendererMode = RendererMode.activeMode

    init(
        debugWorldRunMode: DebugWorldRunMode = .slowInspection,
        showChunkBounds: Bool = true,
        renderTerrain: Bool = true,
        renderProps: Bool = true,
        renderPlayer: Bool = true,
        freezeSimulation: Bool = false,
        freezeChunkStreaming: Bool = false,
        forcedLODLevel: LODLevel? = nil
    ) {
        self.debugWorldRunMode = debugWorldRunMode
        self.showChunkBounds = showChunkBounds
        self.renderTerrain = renderTerrain
        self.renderProps = renderProps
        self.renderPlayer = renderPlayer
        self.freezeSimulation = freezeSimulation
        self.freezeChunkStreaming = freezeChunkStreaming
        self.forcedLODLevel = forcedLODLevel
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
        renderedFrameCount: Int
    ) {
        assignIfNeeded(\.framesPerSecond, framesPerSecond)
        assignIfNeeded(\.frameTimeMilliseconds, frameTimeMilliseconds)
        assignIfNeeded(\.renderedFrameCount, renderedFrameCount)
    }

    func applyPipelineTiming(
        simulationUpdateMs: Float,
        snapshotBuildMs: Float,
        bufferSyncMs: Float,
        renderEncodeMs: Float
    ) {
        assignIfNeeded(\.simulationUpdateMs, simulationUpdateMs)
        assignIfNeeded(\.snapshotBuildMs, snapshotBuildMs)
        assignIfNeeded(\.bufferSyncMs, bufferSyncMs)
        assignIfNeeded(\.renderEncodeMs, renderEncodeMs)
    }

    private func assignIfNeeded<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<DebugMetrics, Value>, _ value: Value) {
        guard self[keyPath: keyPath] != value else {
            return
        }

        self[keyPath: keyPath] = value
    }
}
