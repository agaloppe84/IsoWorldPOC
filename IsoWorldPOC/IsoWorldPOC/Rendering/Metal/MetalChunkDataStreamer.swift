//
//  MetalChunkDataStreamer.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Foundation
import simd

@MainActor
final class MetalChunkDataStreamer {
    private let activeRadiusValue = 1
    private let preloadRadiusValue = 2
    private let maxConcurrentChunkJobs = 2
    private let maxReadyChunksPerFrame = 1

    private var loadedChunkData: [ChunkCoordinate: ProceduralChunkData] = [:]
    private var samplers: [ChunkCoordinate: TerrainSampler] = [:]
    private var pendingChunkQueue: [ChunkCoordinate] = []
    private var pendingChunkSet = Set<ChunkCoordinate>()
    private var generatingChunkSet = Set<ChunkCoordinate>()
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
        generatingChunkSet.count
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

    func makeSnapshot(
        camera: CameraRenderState,
        showChunkBounds: Bool,
        showChunkLabels: Bool
    ) -> RenderWorldSnapshot {
        let chunks = sorted(activeChunkSet).compactMap { coordinate -> RenderChunk? in
            guard let data = loadedChunkData[coordinate] else {
                return nil
            }

            return renderChunk(
                from: data,
                debugState: debugState(for: coordinate)
            )
        }

        return RenderWorldSnapshot(
            camera: camera,
            chunks: chunks,
            debugOptions: RenderDebugOptions(
                showChunkBounds: showChunkBounds,
                showChunkLabels: showChunkLabels
            )
        )
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
    }

    private func enqueueMissingChunks(
        preloadChunks: Set<ChunkCoordinate>,
        activeChunks: Set<ChunkCoordinate>
    ) {
        let candidates = preloadChunks.filter { coordinate in
            loadedChunkData[coordinate] == nil &&
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

            guard desiredPreloadChunks.contains(coordinate), loadedChunkData[coordinate] == nil else {
                continue
            }

            generatingChunkSet.insert(coordinate)

            Task.detached(priority: .utility) { [weak self] in
                let data = ProceduralChunkDataFactory.makeChunkData(coordinate: coordinate)
                await self?.handleGeneratedChunkData(data)
            }
        }
    }

    private func handleGeneratedChunkData(_ data: ProceduralChunkData) {
        generatingChunkSet.remove(data.coordinate)
        chunkDataGenerationSampleCount += 1
        totalChunkDataGenerationTimeMs += data.dataGenerationTimeMs

        if desiredPreloadChunks.contains(data.coordinate), loadedChunkData[data.coordinate] == nil {
            readyChunkData[data.coordinate] = data
        }

        startGenerationJobsIfNeeded()
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

    private func renderChunk(
        from data: ProceduralChunkData,
        debugState: RenderChunkDebugState
    ) -> RenderChunk {
        RenderChunk(
            coordinate: data.coordinate,
            origin: WorldPosition(x: data.originX, y: 0, z: data.originZ),
            terrainGeometry: data.terrainGeometry,
            biome: data.biome,
            terrainMaterial: data.biome.terrainMaterial,
            props: renderProps(from: data),
            debugBounds: RenderChunkDebugBounds(
                coordinate: data.coordinate,
                origin: WorldPosition(x: data.originX, y: 0, z: data.originZ),
                size: PropVector3(
                    x: ProceduralChunkDataFactory.chunkWorldSize,
                    y: 2.5,
                    z: ProceduralChunkDataFactory.chunkWorldSize
                ),
                state: debugState
            ),
            isVisible: activeChunkSet.contains(data.coordinate),
            approximateTriangleCount: data.meshIndices.count / 3
        )
    }

    private func renderProps(from data: ProceduralChunkData) -> [RenderProp] {
        let sampler = TerrainSampler(
            geometry: data.terrainGeometry,
            originX: data.originX,
            originZ: data.originZ
        )

        return data.propVariants.map { variant in
            let localX = variant.placement.localX * ProceduralChunkDataFactory.horizontalScale
            let localZ = variant.placement.localZ * ProceduralChunkDataFactory.horizontalScale
            let worldX = data.originX + localX
            let worldZ = data.originZ + localZ
            let terrainHeight = sampler.heightAt(x: worldX, z: worldZ)

            return RenderProp(
                variant: variant,
                worldPosition: WorldPosition(
                    x: worldX,
                    y: terrainHeight + 0.02,
                    z: worldZ
                ),
                rotationRadians: variant.placement.rotationRadians,
                isVisible: activeChunkSet.contains(data.coordinate)
            )
        }
    }

    private func debugState(for coordinate: ChunkCoordinate) -> RenderChunkDebugState {
        if coordinate == currentChunk {
            return .current
        }

        if generatingChunkSet.contains(coordinate) {
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
