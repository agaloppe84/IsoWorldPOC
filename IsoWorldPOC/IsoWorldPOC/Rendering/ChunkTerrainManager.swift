//
//  ChunkTerrainManager.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import EngineCore
import Foundation
import RealityKit
import simd

@MainActor
final class ChunkTerrainManager {
    private let anchor: Entity
    private let activeRadiusValue = 1
    private let preloadRadiusValue = 2
    private let maxConcurrentChunkJobs = 2
    private let maxChunkUploadsPerFrame = 1

    private var chunks: [ChunkCoordinate: ProceduralTerrainChunk] = [:]
    private var pendingChunkQueue: [ChunkCoordinate] = []
    private var pendingChunkSet = Set<ChunkCoordinate>()
    private var generatingChunkSet = Set<ChunkCoordinate>()
    private var readyChunkData: [ChunkCoordinate: ProceduralChunkData] = [:]
    private var activeChunkSet = Set<ChunkCoordinate>()
    private var desiredPreloadChunks = Set<ChunkCoordinate>()
    private var chunkDebugVisuals: [ChunkCoordinate: ChunkDebugVisualRecord] = [:]
    private var showChunkBounds = true
    private var showChunkLabels = true

    private var chunkDataGenerationSampleCount = 0
    private var chunkUploadSampleCount = 0
    private var totalChunkDataGenerationTimeMs: Float = 0
    private var totalTerrainMeshBuildTimeMs: Float = 0
    private var totalChunkUploadTimeMs: Float = 0
    private var lastChunkUploadsThisFrame = 0

    private(set) var currentChunk = ChunkCoordinate.origin
    private(set) var generatedChunkCount = 0

    var activeRadius: Int {
        activeRadiusValue
    }

    var activeChunkCount: Int {
        activeChunkSet.count
    }

    var visibleChunkCount: Int {
        chunks.keys.filter { activeChunkSet.contains($0) }.count
    }

    var cachedChunkCount: Int {
        chunks.count
    }

    var approximateTriangleCount: Int {
        visibleChunkCount * ProceduralTerrainFactory.triangleCountPerChunk
    }

    var approximatePropCount: Int {
        chunks.reduce(0) { total, entry in
            guard activeChunkSet.contains(entry.key) else {
                return total
            }

            return total + entry.value.propCount
        }
    }

    var chunkJobsQueued: Int {
        pendingChunkQueue.count
    }

    var chunkJobsGenerating: Int {
        generatingChunkSet.count
    }

    var chunksReadyForUpload: Int {
        readyChunkData.count
    }

    var chunkUploadsThisFrame: Int {
        lastChunkUploadsThisFrame
    }

    var averageChunkGenerationTimeMs: Float? {
        averageChunkDataGenerationMs
    }

    var averageChunkDataGenerationMs: Float? {
        average(totalChunkDataGenerationTimeMs, sampleCount: chunkDataGenerationSampleCount)
    }

    var averageTerrainMeshBuildTimeMs: Float? {
        average(totalTerrainMeshBuildTimeMs, sampleCount: chunkUploadSampleCount)
    }

    var averageChunkUploadMs: Float? {
        average(totalChunkUploadTimeMs, sampleCount: chunkUploadSampleCount)
    }

    init(anchor: Entity) {
        self.anchor = anchor
    }

    func setDebugOptions(showChunkBounds: Bool, showChunkLabels: Bool) {
        guard self.showChunkBounds != showChunkBounds || self.showChunkLabels != showChunkLabels else {
            return
        }

        self.showChunkBounds = showChunkBounds
        self.showChunkLabels = showChunkLabels
        syncChunkDebugVisuals()
    }

    func update(around playerPosition: SIMD3<Float>) {
        lastChunkUploadsThisFrame = 0
        currentChunk = chunkCoordinate(containing: playerPosition)

        let activeChunks = requiredChunks(around: currentChunk, radius: activeRadiusValue)
        let preloadChunks = requiredChunks(around: currentChunk, radius: preloadRadiusValue)
        activeChunkSet = activeChunks
        desiredPreloadChunks = preloadChunks

        let loadedChunks = Set(chunks.keys)
        let chunksToUnload = loadedChunks.subtracting(preloadChunks)

        for coordinate in sorted(chunksToUnload) {
            chunks[coordinate]?.entity.removeFromParent()
            chunks.removeValue(forKey: coordinate)
        }

        updateChunkVisibility(activeChunks)
        pruneWorkOutsidePreload(preloadChunks)
        enqueueMissingChunks(preloadChunks: preloadChunks, activeChunks: activeChunks)
        startGenerationJobsIfNeeded()
        uploadReadyChunks(preloadChunks: preloadChunks, activeChunks: activeChunks)
        updateChunkVisibility(activeChunks)
        syncChunkDebugVisuals()
    }

    func updateActiveVisibility(around playerPosition: SIMD3<Float>) {
        currentChunk = chunkCoordinate(containing: playerPosition)
        activeChunkSet = requiredChunks(around: currentChunk, radius: activeRadiusValue)
        updateChunkVisibility(activeChunkSet)
        syncChunkDebugVisuals()
    }

    func terrainSample(at playerPosition: SIMD3<Float>) -> TerrainSampler.Sample? {
        terrainGroundSample(at: playerPosition)?.sample
    }

    func terrainGroundSample(at playerPosition: SIMD3<Float>) -> TerrainGroundSample? {
        let coordinate = chunkCoordinate(containing: playerPosition)
        guard let sample = chunks[coordinate]?.sampler.sampleAt(
            x: playerPosition.x,
            z: playerPosition.z
        ) else {
            return nil
        }

        return TerrainGroundSample(sample: sample, chunk: coordinate)
    }

    private func chunkCoordinate(containing playerPosition: SIMD3<Float>) -> ChunkCoordinate {
        let halfChunkSize = ProceduralTerrainFactory.chunkWorldSize * 0.5

        return ChunkCoordinate(
            x: chunkIndex(for: playerPosition.x + halfChunkSize),
            y: 0,
            z: chunkIndex(for: playerPosition.z + halfChunkSize)
        )
    }

    private func requiredChunks(around currentChunk: ChunkCoordinate, radius: Int) -> Set<ChunkCoordinate> {
        var coordinates = Set<ChunkCoordinate>()
        coordinates.reserveCapacity((radius * 2 + 1) * (radius * 2 + 1))

        for deltaZ in (-radius)...radius {
            for deltaX in (-radius)...radius {
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

    private func pruneWorkOutsidePreload(_ preloadChunks: Set<ChunkCoordinate>) {
        readyChunkData = readyChunkData.filter { preloadChunks.contains($0.key) }

        if pendingChunkQueue.contains(where: { !preloadChunks.contains($0) }) {
            pendingChunkQueue = pendingChunkQueue.filter { preloadChunks.contains($0) }
            pendingChunkSet = Set(pendingChunkQueue)
        }
    }

    private func updateChunkVisibility(_ activeChunks: Set<ChunkCoordinate>) {
        for (coordinate, chunk) in chunks {
            chunk.entity.isEnabled = activeChunks.contains(coordinate)
        }
    }

    private func syncChunkDebugVisuals() {
        guard showChunkBounds || showChunkLabels else {
            removeAllChunkDebugVisuals()
            return
        }

        var desiredCoordinates = activeChunkSet
        desiredCoordinates.formUnion(generatingChunkSet)

        let staleCoordinates = Set(chunkDebugVisuals.keys).subtracting(desiredCoordinates)
        for coordinate in sorted(staleCoordinates) {
            chunkDebugVisuals[coordinate]?.entity.removeFromParent()
            chunkDebugVisuals.removeValue(forKey: coordinate)
        }

        for coordinate in sorted(desiredCoordinates) {
            let state = debugVisualState(for: coordinate)

            if let existing = chunkDebugVisuals[coordinate],
               existing.state == state,
               existing.showBounds == showChunkBounds,
               existing.showLabels == showChunkLabels {
                continue
            }

            chunkDebugVisuals[coordinate]?.entity.removeFromParent()

            let entity = ChunkDebugVisualFactory.makeVisual(
                coordinate: coordinate,
                state: state,
                showBounds: showChunkBounds,
                showLabels: showChunkLabels
            )
            anchor.addChild(entity)
            chunkDebugVisuals[coordinate] = ChunkDebugVisualRecord(
                entity: entity,
                state: state,
                showBounds: showChunkBounds,
                showLabels: showChunkLabels
            )
        }
    }

    private func debugVisualState(for coordinate: ChunkCoordinate) -> ChunkDebugVisualState {
        if coordinate == currentChunk {
            return .current
        }

        if generatingChunkSet.contains(coordinate) {
            return .generating
        }

        return .active
    }

    private func removeAllChunkDebugVisuals() {
        for visual in chunkDebugVisuals.values {
            visual.entity.removeFromParent()
        }

        chunkDebugVisuals.removeAll()
    }

    private func enqueueMissingChunks(
        preloadChunks: Set<ChunkCoordinate>,
        activeChunks: Set<ChunkCoordinate>
    ) {
        let candidates = preloadChunks.filter { coordinate in
            chunks[coordinate] == nil &&
                readyChunkData[coordinate] == nil &&
                !pendingChunkSet.contains(coordinate) &&
                !generatingChunkSet.contains(coordinate)
        }

        for coordinate in sortedByLoadPriority(candidates, activeChunks: activeChunks) {
            pendingChunkQueue.append(coordinate)
            pendingChunkSet.insert(coordinate)
        }
    }

    private func startGenerationJobsIfNeeded() {
        while generatingChunkSet.count < maxConcurrentChunkJobs && !pendingChunkQueue.isEmpty {
            let coordinate = pendingChunkQueue.removeFirst()
            pendingChunkSet.remove(coordinate)

            guard desiredPreloadChunks.contains(coordinate), chunks[coordinate] == nil else {
                continue
            }

            generatingChunkSet.insert(coordinate)

            Task.detached(priority: .utility) { [weak self] in
                let data = ProceduralTerrainFactory.makeChunkData(coordinate: coordinate)
                await self?.handleGeneratedChunkData(data)
            }
        }
    }

    private func handleGeneratedChunkData(_ data: ProceduralChunkData) {
        generatingChunkSet.remove(data.coordinate)
        chunkDataGenerationSampleCount += 1
        totalChunkDataGenerationTimeMs += data.dataGenerationTimeMs

        if desiredPreloadChunks.contains(data.coordinate), chunks[data.coordinate] == nil {
            readyChunkData[data.coordinate] = data
        }

        startGenerationJobsIfNeeded()
    }

    private func uploadReadyChunks(
        preloadChunks: Set<ChunkCoordinate>,
        activeChunks: Set<ChunkCoordinate>
    ) {
        let candidates = preloadChunks.filter { coordinate in
            chunks[coordinate] == nil && readyChunkData[coordinate] != nil
        }

        for coordinate in sortedByLoadPriority(candidates, activeChunks: activeChunks) {
            guard lastChunkUploadsThisFrame < maxChunkUploadsPerFrame else {
                return
            }

            guard let data = readyChunkData.removeValue(forKey: coordinate) else {
                continue
            }

            let uploadStart = currentTimeMilliseconds()

            guard let chunk = ProceduralTerrainFactory.makeChunk(from: data) else {
                continue
            }

            chunk.entity.isEnabled = activeChunks.contains(coordinate)
            anchor.addChild(chunk.entity)
            chunks[coordinate] = chunk
            generatedChunkCount += 1
            lastChunkUploadsThisFrame += 1
            recordUploadMetrics(
                chunk.buildMetrics,
                uploadTimeMs: Float(currentTimeMilliseconds() - uploadStart)
            )
        }
    }

    private func recordUploadMetrics(
        _ metrics: ProceduralChunkBuildMetrics,
        uploadTimeMs: Float
    ) {
        chunkUploadSampleCount += 1
        totalTerrainMeshBuildTimeMs += metrics.terrainMeshBuildTimeMs
        totalChunkUploadTimeMs += uploadTimeMs
    }

    private func average(_ total: Float, sampleCount: Int) -> Float? {
        guard sampleCount > 0 else {
            return nil
        }

        return total / Float(sampleCount)
    }

    private func sortedByLoadPriority(
        _ coordinates: Set<ChunkCoordinate>,
        activeChunks: Set<ChunkCoordinate>
    ) -> [ChunkCoordinate] {
        coordinates.sorted { first, second in
            let firstIsActive = activeChunks.contains(first)
            let secondIsActive = activeChunks.contains(second)

            if firstIsActive != secondIsActive {
                return firstIsActive
            }

            let firstDistance = distance(from: currentChunk, to: first)
            let secondDistance = distance(from: currentChunk, to: second)

            if firstDistance != secondDistance {
                return firstDistance < secondDistance
            }

            if first.z != second.z {
                return first.z < second.z
            }

            if first.x != second.x {
                return first.x < second.x
            }

            return first.y < second.y
        }
    }

    private func distance(from origin: ChunkCoordinate, to coordinate: ChunkCoordinate) -> Int {
        abs(coordinate.x - origin.x) + abs(coordinate.z - origin.z)
    }

    private func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
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

private struct ChunkDebugVisualRecord {
    let entity: Entity
    let state: ChunkDebugVisualState
    let showBounds: Bool
    let showLabels: Bool
}
