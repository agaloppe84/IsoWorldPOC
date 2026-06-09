//
//  ChunkTerrainManager.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import EngineCore
import RealityKit
import simd

@MainActor
final class ChunkTerrainManager {
    private let anchor: Entity
    private let activeRadiusValue = 1
    private var chunks: [ChunkCoordinate: ProceduralTerrainChunk] = [:]
    private var chunkBuildSampleCount = 0
    private var totalChunkGenerationTimeMs: Float = 0
    private var totalTerrainMeshBuildTimeMs: Float = 0

    private(set) var currentChunk = ChunkCoordinate.origin
    private(set) var generatedChunkCount = 0

    var activeRadius: Int {
        activeRadiusValue
    }

    var activeChunkCount: Int {
        chunks.count
    }

    var visibleChunkCount: Int {
        chunks.count
    }

    var cachedChunkCount: Int {
        chunks.count
    }

    var approximateTriangleCount: Int {
        activeChunkCount * ProceduralTerrainFactory.triangleCountPerChunk
    }

    var approximatePropCount: Int {
        chunks.values.reduce(0) { total, chunk in
            total + chunk.propCount
        }
    }

    var averageChunkGenerationTimeMs: Float? {
        average(totalChunkGenerationTimeMs)
    }

    var averageTerrainMeshBuildTimeMs: Float? {
        average(totalTerrainMeshBuildTimeMs)
    }

    init(anchor: Entity) {
        self.anchor = anchor
    }

    func update(around playerPosition: SIMD3<Float>) {
        currentChunk = chunkCoordinate(containing: playerPosition)

        let requiredChunks = requiredChunks(around: currentChunk)
        let loadedChunks = Set(chunks.keys)
        let chunksToUnload = loadedChunks.subtracting(requiredChunks)
        let chunksToLoad = requiredChunks.subtracting(loadedChunks)

        for coordinate in sorted(chunksToUnload) {
            chunks[coordinate]?.entity.removeFromParent()
            chunks.removeValue(forKey: coordinate)
        }

        for coordinate in sorted(chunksToLoad) {
            guard let chunk = ProceduralTerrainFactory.makeChunk(coordinate: coordinate) else {
                continue
            }

            anchor.addChild(chunk.entity)
            chunks[coordinate] = chunk
            generatedChunkCount += 1
            recordBuildMetrics(chunk.buildMetrics)
        }
    }

    func terrainSample(at playerPosition: SIMD3<Float>) -> TerrainSampler.Sample? {
        let coordinate = chunkCoordinate(containing: playerPosition)
        return chunks[coordinate]?.sampler.sampleAt(
            x: playerPosition.x,
            z: playerPosition.z
        )
    }

    private func chunkCoordinate(containing playerPosition: SIMD3<Float>) -> ChunkCoordinate {
        let halfChunkSize = ProceduralTerrainFactory.chunkWorldSize * 0.5

        return ChunkCoordinate(
            x: chunkIndex(for: playerPosition.x + halfChunkSize),
            y: 0,
            z: chunkIndex(for: playerPosition.z + halfChunkSize)
        )
    }

    private func requiredChunks(around currentChunk: ChunkCoordinate) -> Set<ChunkCoordinate> {
        var coordinates = Set<ChunkCoordinate>()
        coordinates.reserveCapacity((activeRadiusValue * 2 + 1) * (activeRadiusValue * 2 + 1))

        for deltaZ in (-activeRadiusValue)...activeRadiusValue {
            for deltaX in (-activeRadiusValue)...activeRadiusValue {
                coordinates.insert(
                    ChunkCoordinate(
                        x: currentChunk.x + deltaX,
                        y: 0,
                        z: currentChunk.z + deltaZ
                    )
                )
            }
        }

        return coordinates
    }

    private func chunkIndex(for value: Float) -> Int {
        Int((value / ProceduralTerrainFactory.chunkWorldSize).rounded(.down))
    }

    private func recordBuildMetrics(_ metrics: ProceduralChunkBuildMetrics) {
        chunkBuildSampleCount += 1
        totalChunkGenerationTimeMs += metrics.chunkGenerationTimeMs
        totalTerrainMeshBuildTimeMs += metrics.terrainMeshBuildTimeMs
    }

    private func average(_ total: Float) -> Float? {
        guard chunkBuildSampleCount > 0 else {
            return nil
        }

        return total / Float(chunkBuildSampleCount)
    }

    private func sorted(_ coordinates: Set<ChunkCoordinate>) -> [ChunkCoordinate] {
        coordinates.sorted { first, second in
            if first.z != second.z {
                return first.z < second.z
            }

            if first.x != second.x {
                return first.x < second.x
            }

            return first.y < second.y
        }
    }
}
