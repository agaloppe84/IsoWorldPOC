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
    @Published var currentChunk = ChunkCoordinate.origin
    @Published var activeChunkCount = 0
    @Published var visibleChunkCount = 0
    @Published var generatedChunkCount = 0
    @Published var cachedChunkCount = 0
    @Published var approximateTriangleCount = 0
    @Published var approximatePropCount = 0
    @Published var averageChunkGenerationTimeMs: Float?
    @Published var averageTerrainMeshBuildTimeMs: Float?
}
