//
//  RenderPayloadUploader.swift
//  IsoWorldPOC
//
//  Created by Work on 11/06/2026.
//

import EngineCore
import Foundation
import Metal

final class RenderPayloadUploader {
    private let device: MTLDevice?
    let maxChunkUploadsPerFrame: Int

    private(set) var chunkUploadsThisFrame = 0
    private(set) var chunkUploadSampleCount = 0
    private(set) var totalChunkUploadTimeMs: Float = 0

    init(device: MTLDevice?, maxChunkUploadsPerFrame: Int = 12) {
        self.device = device
        self.maxChunkUploadsPerFrame = max(maxChunkUploadsPerFrame, 1)
    }

    var averageChunkUploadMs: Float? {
        guard chunkUploadSampleCount > 0 else {
            return nil
        }

        return totalChunkUploadTimeMs / Float(chunkUploadSampleCount)
    }

    func sync(
        snapshot: RenderWorldSnapshot,
        registry: GPUResourceRegistry
    ) {
        chunkUploadsThisFrame = 0

        let requiredCoordinates = Set(snapshot.chunks.filter(\.isVisible).map(\.coordinate))
        registry.removeChunks(except: requiredCoordinates)

        for chunk in uploadCandidates(from: snapshot, registry: registry) {
            guard chunkUploadsThisFrame < maxChunkUploadsPerFrame else {
                break
            }

            let uploadStart = currentTimeMilliseconds()
            guard let buffers = MetalChunkBuffers(device: device, renderChunk: chunk) else {
                continue
            }

            registry.store(buffers, for: chunk.coordinate)
            chunkUploadsThisFrame += 1
            chunkUploadSampleCount += 1
            totalChunkUploadTimeMs += Float(currentTimeMilliseconds() - uploadStart)
        }
    }

    private func uploadCandidates(
        from snapshot: RenderWorldSnapshot,
        registry: GPUResourceRegistry
    ) -> [RenderChunk] {
        snapshot.chunks
            .filter { $0.isVisible && registry.needsChunkBufferUpload(for: $0) }
            .sorted { lhs, rhs in
                return isCoordinate(lhs.coordinate, orderedBefore: rhs.coordinate)
            }
    }

    private func isCoordinate(
        _ lhs: ChunkCoordinate,
        orderedBefore rhs: ChunkCoordinate
    ) -> Bool {
        if lhs.x != rhs.x {
            return lhs.x < rhs.x
        }

        if lhs.y != rhs.y {
            return lhs.y < rhs.y
        }

        return lhs.z < rhs.z
    }

    private func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
