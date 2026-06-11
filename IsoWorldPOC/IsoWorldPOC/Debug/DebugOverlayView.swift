//
//  DebugOverlayView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import Foundation
import EngineCore
import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject var metrics: DebugMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("PERF")
            Text("renderer: \(metrics.rendererMode.displayName)")
            Picker("run mode", selection: $metrics.debugWorldRunMode) {
                ForEach(DebugWorldRunMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("fps / frame: \(format(metrics.framesPerSecond)) / \(format(metrics.frameTimeMilliseconds)) ms")
            Text("chunk data avg: \(format(metrics.averageChunkDataGenerationMs)) ms")
            Text("chunk upload avg: \(format(metrics.averageChunkUploadMs)) ms")
            Text("draw calls total: \(metrics.metalDrawCallCount)")
            Text("terrain textures arrays/layers: \(metrics.metalTerrainTextureArrayCount) / \(metrics.metalTerrainTextureLayerCount)")
            Picker("terrain material", selection: $metrics.terrainMaterialDebugMode) {
                ForEach(TerrainMaterialDebugMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            Stepper(
                "splat layer: \(metrics.terrainSplatDebugLayerIndex)",
                value: $metrics.terrainSplatDebugLayerIndex,
                in: 0...(TerrainMaterialSplat.maxLayerCount - 1)
            )

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("PLAYER")
            Text("position x/y/z: \(format(metrics.playerPosition.x)) / \(format(metrics.playerPosition.y)) / \(format(metrics.playerPosition.z))")
            Text("currentChunk x/y/z: \(metrics.currentChunk.x) / \(metrics.currentChunk.y) / \(metrics.currentChunk.z)")
            Text("ground y / slope: \(format(metrics.terrainHeightUnderPlayer)) / \(format(metrics.slopeUnderPlayer))")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("CHUNKS")
            Text("active / visible / cached: \(metrics.activeChunkCount) / \(metrics.visibleChunkCount) / \(metrics.cachedChunkCount)")
            Text("lod candidates / culled: \(metrics.lodCandidateChunkCount) / \(metrics.lodCulledChunkCount)")
            Text("lod 0/1/2/3: \(metrics.lod0ChunkCount) / \(metrics.lod1ChunkCount) / \(metrics.lod2ChunkCount) / \(metrics.lod3ChunkCount)")
            Text("triangles / props: \(metrics.approximateTriangleCount) / \(metrics.approximatePropCount)")
            Text("drawn chunks / props: \(metrics.metalRenderedChunkCount) / \(metrics.metalRenderedPropCount)")
            Text("jobs queued / gen / ready: \(metrics.chunkJobsQueued) / \(metrics.chunkJobsGenerating) / \(metrics.chunksReadyForUpload)")
            Text("uploads this frame: \(metrics.chunkUploadsThisFrame)")
            Toggle("showChunkBounds", isOn: $metrics.showChunkBounds)
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .toggleStyle(.checkbox)
        .padding(12)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.72))
    }

    private func format(_ value: Float) -> String {
        String(format: "%.2f", value)
    }

    private func format(_ value: Float?) -> String {
        guard let value else {
            return "n/a"
        }

        return format(value)
    }

}
