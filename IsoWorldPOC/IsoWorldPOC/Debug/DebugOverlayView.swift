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
        let telemetry = metrics.telemetry

        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("PERF")
            Text("renderer: \(telemetry.rendererMode.displayName)")
            Picker("run mode", selection: $metrics.debugWorldRunMode) {
                ForEach(DebugWorldRunMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text("fps / frame: \(format(telemetry.framesPerSecond)) / \(format(telemetry.frameTimeMilliseconds)) ms")
            Text("frame raw / draw / gap: \(format(telemetry.rawFrameIntervalMs)) / \(format(telemetry.drawTotalMs)) / \(format(telemetry.frameSchedulingGapMs)) ms")
            Text("cpu sim / snapshot: \(format(telemetry.simulationUpdateMs)) / \(format(telemetry.snapshotBuildMs)) ms")
            Text("buffer sync / encode: \(format(telemetry.bufferSyncMs)) / \(format(telemetry.renderEncodeMs)) ms")
            Text("publish / unaccounted: \(format(telemetry.debugMetricsPublishMs)) / \(format(telemetry.unaccountedDrawMs)) ms")
            Text("snapshot active/chunks/props/sample: \(format(telemetry.snapshotActiveChunkDataMs)) / \(format(telemetry.snapshotRenderChunksMs)) / \(format(telemetry.snapshotRenderPropsMs)) / \(format(telemetry.snapshotTerrainSamplePropsMs)) ms")
            Text("snapshot chunks / props: \(telemetry.snapshotChunkCount) / \(telemetry.snapshotPropCount)")
            Text("chunk data avg: \(format(telemetry.averageChunkDataGenerationMs)) ms")
            Text("chunk upload avg: \(format(telemetry.averageChunkUploadMs)) ms")
            Text("draw calls total: \(telemetry.metalDrawCallCount)")
            Text("indices terrain / props: \(telemetry.metalVisibleTerrainIndexCount) / \(telemetry.metalVisiblePropIndexCount)")
            Text("memory cpu/gpu: \(formatBytes(telemetry.estimatedChunkCPUBytes)) / \(formatBytes(telemetry.estimatedGPUBufferBytes))")
            Text("terrain textures arrays/layers: \(telemetry.metalTerrainTextureArrayCount) / \(telemetry.metalTerrainTextureLayerCount)")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("ISOLATION")
            Toggle("render terrain", isOn: $metrics.renderTerrain)
            Toggle("render props", isOn: $metrics.renderProps)
            Toggle("render player", isOn: $metrics.renderPlayer)
            Toggle("show chunk bounds", isOn: $metrics.showChunkBounds)
            Toggle("freeze simulation", isOn: $metrics.freezeSimulation)
            Toggle("freeze streaming", isOn: $metrics.freezeChunkStreaming)
            Toggle("pause metrics publish", isOn: $metrics.pauseDebugMetricPublishing)
            Picker("force LOD", selection: $metrics.forcedLODLevel) {
                Text("Auto").tag(nil as LODLevel?)
                ForEach(LODLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(Optional(level))
                }
            }
            .pickerStyle(.menu)

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("MATERIAL")
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
            Text("position x/y/z: \(format(telemetry.playerPosition.x)) / \(format(telemetry.playerPosition.y)) / \(format(telemetry.playerPosition.z))")
            Text("currentChunk x/y/z: \(telemetry.currentChunk.x) / \(telemetry.currentChunk.y) / \(telemetry.currentChunk.z)")
            Text("ground y / slope: \(format(telemetry.terrainHeightUnderPlayer)) / \(format(telemetry.slopeUnderPlayer))")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("CHUNKS")
            Text("active / visible / cached: \(telemetry.activeChunkCount) / \(telemetry.visibleChunkCount) / \(telemetry.cachedChunkCount)")
            Text("lod candidates / culled: \(telemetry.lodCandidateChunkCount) / \(telemetry.lodCulledChunkCount)")
            Text("lod 0/1/2/3: \(telemetry.lod0ChunkCount) / \(telemetry.lod1ChunkCount) / \(telemetry.lod2ChunkCount) / \(telemetry.lod3ChunkCount)")
            Text("triangles / props: \(telemetry.approximateTriangleCount) / \(telemetry.approximatePropCount)")
            Text("drawn chunks / props: \(telemetry.metalRenderedChunkCount) / \(telemetry.metalRenderedPropCount)")
            Text("jobs queued / gen / ready: \(telemetry.chunkJobsQueued) / \(telemetry.chunkJobsGenerating) / \(telemetry.chunksReadyForUpload)")
            Text("uploads this frame: \(telemetry.chunkUploadsThisFrame)")
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

    private func formatBytes(_ value: Int) -> String {
        let kilobytes = Double(value) / 1_024

        guard kilobytes >= 1_024 else {
            return String(format: "%.0f KB", kilobytes)
        }

        return String(format: "%.1f MB", kilobytes / 1_024)
    }

}
