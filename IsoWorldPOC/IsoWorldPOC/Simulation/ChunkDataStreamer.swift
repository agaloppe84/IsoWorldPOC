//
//  ChunkDataStreamer.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Foundation
import simd

@MainActor
final class ChunkDataStreamer {
    private let activeRadiusValue = 1
    private let preloadRadiusValue = 2
    private let maxConcurrentChunkJobs = 2
    private let maxReadyChunksPerFrame = 1
    private let chunkJobScheduler = JobScheduler()

    private var loadedChunkData: [ChunkCoordinate: ProceduralChunkData] = [:]
    private var samplers: [ChunkCoordinate: TerrainSampler] = [:]
    private var pendingChunkQueue: [ChunkCoordinate] = []
    private var pendingChunkSet = Set<ChunkCoordinate>()
    private var chunkJobHandles: [ChunkCoordinate: JobHandle<ProceduralChunkData>] = [:]
    private var readyChunkData: [ChunkCoordinate: ProceduralChunkData] = [:]
    private var activeChunkSet = Set<ChunkCoordinate>()
    private var desiredPreloadChunks = Set<ChunkCoordinate>()

    private var chunkDataGenerationSampleCount = 0
    private var totalChunkDataGenerationTimeMs: Float = 0
    private var lastReadyChunksActivatedThisFrame = 0

    private(set) var currentChunk = ChunkCoordinate.origin
    private(set) var generatedChunkCount = 0

    init() {
        let initialData = ProceduralChunkDataFactory.makeChunkData(coordinate: .origin)
        loadChunkData(initialData)
        generatedChunkCount = 1
    }

    deinit {
        chunkJobScheduler.cancelAll()
    }

    var activeChunkCount: Int {
        activeChunkSet.count
    }

    var visibleChunkCount: Int {
        loadedChunkData.keys.filter { activeChunkSet.contains($0) }.count
    }

    var cachedChunkCount: Int {
        loadedChunkData.count
    }

    var approximateTriangleCount: Int {
        visibleChunkCount * ProceduralChunkDataFactory.triangleCountPerChunk
    }

    var approximatePropCount: Int {
        loadedChunkData.reduce(0) { total, entry in
            guard activeChunkSet.contains(entry.key) else {
                return total
            }

            return total + entry.value.propVariants.count
        }
    }

    var chunkJobsQueued: Int {
        pendingChunkQueue.count
    }

    var chunkJobsGenerating: Int {
        chunkJobHandles.count
    }

    var chunksReadyForUpload: Int {
        readyChunkData.count
    }

    var readyChunksActivatedThisFrame: Int {
        lastReadyChunksActivatedThisFrame
    }

    var averageChunkDataGenerationMs: Float? {
        average(totalChunkDataGenerationTimeMs, sampleCount: chunkDataGenerationSampleCount)
    }

    var jobSchedulerSnapshot: JobSchedulerSnapshot {
        chunkJobScheduler.snapshot
    }

    func activeChunkData() -> [ChunkStreamerRenderData] {
        sorted(activeChunkSet).compactMap { coordinate in
            guard let data = loadedChunkData[coordinate] else {
                return nil
            }

            return ChunkStreamerRenderData(
                data: data,
                debugState: debugState(for: coordinate),
                isVisible: activeChunkSet.contains(coordinate)
            )
        }
    }

    func debugSnapshot(
        frameIndex: UInt64,
        currentGroundChunk: ChunkCoordinate?
    ) -> DebugSnapshot {
        DebugSnapshot(
            frameIndex: frameIndex,
            currentChunk: currentChunk,
            currentGroundChunk: currentGroundChunk,
            activeChunkCount: activeChunkCount,
            visibleChunkCount: visibleChunkCount,
            generatedChunkCount: generatedChunkCount,
            cachedChunkCount: cachedChunkCount,
            approximateTriangleCount: approximateTriangleCount,
            approximatePropCount: approximatePropCount,
            jobs: jobSchedulerSnapshot,
            chunksReadyForUpload: chunksReadyForUpload,
            chunkUploadsThisFrame: readyChunksActivatedThisFrame,
            averageChunkDataGenerationTimeMs: averageChunkDataGenerationMs
        )
    }

    func update(around playerPosition: SIMD3<Float>) {
        lastReadyChunksActivatedThisFrame = 0
        currentChunk = chunkCoordinate(containing: playerPosition)

        let activeChunks = requiredChunks(around: currentChunk, radius: activeRadiusValue)
        let preloadChunks = requiredChunks(around: currentChunk, radius: preloadRadiusValue)
        activeChunkSet = activeChunks
        desiredPreloadChunks = preloadChunks

        unloadChunksOutside(preloadChunks)
        pruneWorkOutsidePreload(preloadChunks)
        enqueueMissingChunks(preloadChunks: preloadChunks, activeChunks: activeChunks)
        startGenerationJobsIfNeeded()
        activateReadyChunks(preloadChunks: preloadChunks, activeChunks: activeChunks)
    }

    func updateActiveVisibility(around playerPosition: SIMD3<Float>) {
        currentChunk = chunkCoordinate(containing: playerPosition)
        activeChunkSet = requiredChunks(around: currentChunk, radius: activeRadiusValue)
    }

    func terrainGroundSample(at playerPosition: SIMD3<Float>) -> TerrainGroundSample? {
        let coordinate = chunkCoordinate(containing: playerPosition)
        guard let sample = samplers[coordinate]?.sampleAt(
            x: playerPosition.x,
            z: playerPosition.z
        ) else {
            return nil
        }

        return TerrainGroundSample(sample: sample, chunk: coordinate)
    }

    private func loadChunkData(_ data: ProceduralChunkData) {
        loadedChunkData[data.coordinate] = data
        samplers[data.coordinate] = TerrainSampler(
            geometry: data.terrainGeometry,
            originX: data.originX,
            originZ: data.originZ
        )
    }

    private func unloadChunksOutside(_ preloadChunks: Set<ChunkCoordinate>) {
        let staleCoordinates = Set(loadedChunkData.keys).subtracting(preloadChunks)

        for coordinate in sorted(staleCoordinates) {
            loadedChunkData.removeValue(forKey: coordinate)
            samplers.removeValue(forKey: coordinate)
        }
    }

    private func pruneWorkOutsidePreload(_ preloadChunks: Set<ChunkCoordinate>) {
        readyChunkData = readyChunkData.filter { preloadChunks.contains($0.key) }

        if pendingChunkQueue.contains(where: { !preloadChunks.contains($0) }) {
            pendingChunkQueue = pendingChunkQueue.filter { preloadChunks.contains($0) }
            pendingChunkSet = Set(pendingChunkQueue)
        }

        for coordinate in chunkJobHandles.keys where !preloadChunks.contains(coordinate) {
            chunkJobHandles[coordinate]?.cancel()
        }
    }

    private func enqueueMissingChunks(
        preloadChunks: Set<ChunkCoordinate>,
        activeChunks: Set<ChunkCoordinate>
    ) {
        let candidates = preloadChunks.filter { coordinate in
            loadedChunkData[coordinate] == nil &&
                readyChunkData[coordinate] == nil &&
                !pendingChunkSet.contains(coordinate) &&
                chunkJobHandles[coordinate] == nil
        }

        for coordinate in sortedByLoadPriority(candidates, activeChunks: activeChunks) {
            pendingChunkQueue.append(coordinate)
            pendingChunkSet.insert(coordinate)
        }
    }

    private func startGenerationJobsIfNeeded() {
        while chunkJobHandles.count < maxConcurrentChunkJobs && !pendingChunkQueue.isEmpty {
            let coordinate = pendingChunkQueue.removeFirst()
            pendingChunkSet.remove(coordinate)

            guard desiredPreloadChunks.contains(coordinate), loadedChunkData[coordinate] == nil else {
                continue
            }

            let job = EngineJob<ProceduralChunkData>(
                name: "generate-chunk-\(coordinate.x)-\(coordinate.y)-\(coordinate.z)",
                priority: .utility
            ) { cancellationToken in
                try ProceduralChunkDataFactory.makeChunkData(
                    coordinate: coordinate,
                    cancellationToken: cancellationToken
                )
            }
            let handle = chunkJobScheduler.submit(job)
            let jobID = handle.id
            chunkJobHandles[coordinate] = handle

            Task { [weak self, handle, coordinate, jobID] in
                do {
                    let data = try await handle.value()
                    self?.handleGeneratedChunkData(data, jobID: jobID)
                } catch {
                    self?.handleChunkJobFailure(coordinate: coordinate, jobID: jobID)
                }
            }
        }
    }

    private func handleGeneratedChunkData(_ data: ProceduralChunkData, jobID: EngineJobID) {
        guard completeChunkJob(coordinate: data.coordinate, jobID: jobID) else {
            return
        }

        chunkDataGenerationSampleCount += 1
        totalChunkDataGenerationTimeMs += data.dataGenerationTimeMs

        if desiredPreloadChunks.contains(data.coordinate), loadedChunkData[data.coordinate] == nil {
            readyChunkData[data.coordinate] = data
        }

        startGenerationJobsIfNeeded()
    }

    private func handleChunkJobFailure(coordinate: ChunkCoordinate, jobID: EngineJobID) {
        guard completeChunkJob(coordinate: coordinate, jobID: jobID) else {
            return
        }

        startGenerationJobsIfNeeded()
    }

    private func completeChunkJob(coordinate: ChunkCoordinate, jobID: EngineJobID) -> Bool {
        guard chunkJobHandles[coordinate]?.id == jobID else {
            return false
        }

        chunkJobHandles.removeValue(forKey: coordinate)
        return true
    }

    private func activateReadyChunks(
        preloadChunks: Set<ChunkCoordinate>,
        activeChunks: Set<ChunkCoordinate>
    ) {
        let candidates = preloadChunks.filter { coordinate in
            loadedChunkData[coordinate] == nil && readyChunkData[coordinate] != nil
        }

        for coordinate in sortedByLoadPriority(candidates, activeChunks: activeChunks) {
            guard lastReadyChunksActivatedThisFrame < maxReadyChunksPerFrame else {
                return
            }

            guard let data = readyChunkData.removeValue(forKey: coordinate) else {
                continue
            }

            loadChunkData(data)
            generatedChunkCount += 1
            lastReadyChunksActivatedThisFrame += 1
        }
    }

    private func debugState(for coordinate: ChunkCoordinate) -> RenderChunkDebugState {
        if coordinate == currentChunk {
            return .current
        }

        if chunkJobHandles[coordinate] != nil {
            return .generating
        }

        return .active
    }

    private func chunkCoordinate(containing playerPosition: SIMD3<Float>) -> ChunkCoordinate {
        let halfChunkSize = ProceduralChunkDataFactory.chunkWorldSize * 0.5

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
        Int((value / ProceduralChunkDataFactory.chunkWorldSize).rounded(.down))
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

    private func average(_ total: Float, sampleCount: Int) -> Float? {
        guard sampleCount > 0 else {
            return nil
        }

        return total / Float(sampleCount)
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

struct ChunkStreamerRenderData {
    let data: ProceduralChunkData
    let debugState: RenderChunkDebugState
    let isVisible: Bool
}
