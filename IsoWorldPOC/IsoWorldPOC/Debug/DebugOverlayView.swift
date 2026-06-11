//
//  DebugOverlayView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import EngineCore
import Foundation
import SwiftUI

struct DebugOverlayView: View {
    let metrics: DebugMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DebugPerfTelemetryView(store: metrics.telemetryStore)

            Divider().overlay(.white.opacity(0.35))

            DebugControlsView(metrics: metrics)

            Divider().overlay(.white.opacity(0.35))

            DebugWorldTelemetryView(store: metrics.telemetryStore)
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
}

private struct DebugPerfTelemetryView: View {
    @ObservedObject var store: DebugTelemetryStore

    var body: some View {
        let telemetry = store.telemetry

        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("PERF")
            Text(perfText(for: telemetry))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func perfText(for telemetry: DebugTelemetry) -> String {
        [
            "renderer: \(telemetry.rendererMode.displayName)",
            "fps / frame: \(format(telemetry.framesPerSecond)) / \(format(telemetry.frameTimeMilliseconds)) ms",
            "frame raw / draw / gap: \(format(telemetry.rawFrameIntervalMs)) / \(format(telemetry.drawTotalMs)) / \(format(telemetry.frameSchedulingGapMs)) ms",
            "cpu sim / snapshot: \(format(telemetry.simulationUpdateMs)) / \(format(telemetry.snapshotBuildMs)) ms",
            "buffer sync / encode: \(format(telemetry.bufferSyncMs)) / \(format(telemetry.renderEncodeMs)) ms",
            "publish / unaccounted: \(format(telemetry.debugMetricsPublishMs)) / \(format(telemetry.unaccountedDrawMs)) ms",
            "snapshot active/chunks/props/sample: \(format(telemetry.snapshotActiveChunkDataMs)) / \(format(telemetry.snapshotRenderChunksMs)) / \(format(telemetry.snapshotRenderPropsMs)) / \(format(telemetry.snapshotTerrainSamplePropsMs)) ms",
            "snapshot chunks / props: \(telemetry.snapshotChunkCount) / \(telemetry.snapshotPropCount)",
            "chunk data avg: \(format(telemetry.averageChunkDataGenerationMs)) ms",
            "chunk upload avg: \(format(telemetry.averageChunkUploadMs)) ms",
            "draw calls total: \(telemetry.metalDrawCallCount)",
            "indices terrain / props: \(telemetry.metalVisibleTerrainIndexCount) / \(telemetry.metalVisiblePropIndexCount)",
            "memory cpu/gpu: \(formatBytes(telemetry.estimatedChunkCPUBytes)) / \(formatBytes(telemetry.estimatedGPUBufferBytes))",
            "terrain textures arrays/layers: \(telemetry.metalTerrainTextureArrayCount) / \(telemetry.metalTerrainTextureLayerCount)"
        ].joined(separator: "\n")
    }
}

private struct DebugControlsView: View {
    @ObservedObject var metrics: DebugMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("RUN")
            Picker("run mode", selection: $metrics.debugWorldRunMode) {
                ForEach(DebugWorldRunMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

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
        }
    }
}

private struct DebugWorldTelemetryView: View {
    @ObservedObject var store: DebugTelemetryStore

    var body: some View {
        let telemetry = store.telemetry

        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("PLAYER")
            Text(playerText(for: telemetry))
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("CHUNKS")
            Text(chunkText(for: telemetry))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func playerText(for telemetry: DebugTelemetry) -> String {
        [
            "position x/y/z: \(format(telemetry.playerPosition.x)) / \(format(telemetry.playerPosition.y)) / \(format(telemetry.playerPosition.z))",
            "currentChunk x/y/z: \(telemetry.currentChunk.x) / \(telemetry.currentChunk.y) / \(telemetry.currentChunk.z)",
            "ground y / slope: \(format(telemetry.terrainHeightUnderPlayer)) / \(format(telemetry.slopeUnderPlayer))"
        ].joined(separator: "\n")
    }

    private func chunkText(for telemetry: DebugTelemetry) -> String {
        [
            "active / visible / cached: \(telemetry.activeChunkCount) / \(telemetry.visibleChunkCount) / \(telemetry.cachedChunkCount)",
            "lod candidates / culled: \(telemetry.lodCandidateChunkCount) / \(telemetry.lodCulledChunkCount)",
            "lod 0/1/2/3: \(telemetry.lod0ChunkCount) / \(telemetry.lod1ChunkCount) / \(telemetry.lod2ChunkCount) / \(telemetry.lod3ChunkCount)",
            "triangles / props: \(telemetry.approximateTriangleCount) / \(telemetry.approximatePropCount)",
            "drawn chunks / props: \(telemetry.metalRenderedChunkCount) / \(telemetry.metalRenderedPropCount)",
            "jobs queued / gen / ready: \(telemetry.chunkJobsQueued) / \(telemetry.chunkJobsGenerating) / \(telemetry.chunksReadyForUpload)",
            "uploads this frame: \(telemetry.chunkUploadsThisFrame)"
        ].joined(separator: "\n")
    }
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
