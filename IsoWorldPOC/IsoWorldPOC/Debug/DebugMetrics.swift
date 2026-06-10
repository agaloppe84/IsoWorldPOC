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
    @Published var inputState = PlayerInputState()
    @Published var controllerName = "None"
    @Published var playerPosition = SIMD3<Float>(0, 0, 0)
    @Published var terrainHeightUnderPlayer: Float?
    @Published var terrainSlopeUnderPlayer: Float?
    @Published var slopeUnderPlayer: Float?
    @Published var playerGrounded = false
    @Published var maxWalkableSlope: Float = 0
    @Published var currentChunk = ChunkCoordinate.origin
    @Published var currentGroundChunk: ChunkCoordinate?
    @Published var activeChunkCount = 0
    @Published var visibleChunkCount = 0
    @Published var generatedChunkCount = 0
    @Published var cachedChunkCount = 0
    @Published var approximateTriangleCount = 0
    @Published var approximatePropCount = 0
    @Published var averageChunkGenerationTimeMs: Float?
    @Published var averageTerrainMeshBuildTimeMs: Float?
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
    @Published var metalBufferCount = 0
    @Published var metalRenderedChunkCount = 0
    @Published var metalRenderedPropCount = 0
    @Published var metalVisibleTerrainMaterialCount = 0
    @Published var metalVisiblePropMaterialCount = 0
    @Published var showChunkBounds = true
    @Published var showChunkLabels = true
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
}
