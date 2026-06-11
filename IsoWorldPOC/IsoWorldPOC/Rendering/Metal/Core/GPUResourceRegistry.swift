//
//  GPUResourceRegistry.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import EngineCore

final class GPUResourceRegistry {
    private(set) var chunkBuffersByCoordinate: [ChunkCoordinate: MetalChunkBuffers] = [:]
    let playerBuffers: MetalIndexedMeshBuffers?

    init(playerBuffers: MetalIndexedMeshBuffers?) {
        self.playerBuffers = playerBuffers
    }

    var cachedChunkCount: Int {
        chunkBuffersByCoordinate.count
    }

    var bufferCount: Int {
        let playerBufferCount = playerBuffers?.bufferCount ?? 0

        return chunkBuffersByCoordinate.values.reduce(playerBufferCount) { total, buffers in
            total + buffers.bufferCount
        }
    }

    func removeChunks(except requiredCoordinates: Set<ChunkCoordinate>) {
        for loadedCoordinate in Array(chunkBuffersByCoordinate.keys) where !requiredCoordinates.contains(loadedCoordinate) {
            chunkBuffersByCoordinate.removeValue(forKey: loadedCoordinate)
        }
    }

    func needsChunkBufferUpload(for chunk: RenderChunk) -> Bool {
        guard let buffers = chunkBuffersByCoordinate[chunk.coordinate] else {
            return true
        }

        return buffers.renderChunk.lodSelection.level != chunk.lodSelection.level ||
            buffers.renderChunk.lodSelection.rendersProps != chunk.lodSelection.rendersProps
    }

    func store(_ buffers: MetalChunkBuffers, for coordinate: ChunkCoordinate) {
        chunkBuffersByCoordinate[coordinate] = buffers
    }
}
