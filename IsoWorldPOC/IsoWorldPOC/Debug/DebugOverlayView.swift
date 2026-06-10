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

    private var input: PlayerInputState {
        metrics.inputState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("PERF")
            Text("renderer: \(metrics.rendererMode.displayName)")
            Text("fps / frame: \(format(metrics.framesPerSecond)) / \(format(metrics.frameTimeMilliseconds)) ms")
            Text("chunk data avg: \(format(metrics.averageChunkDataGenerationMs)) ms")
            Text("chunk upload avg: \(format(metrics.averageChunkUploadMs)) ms")
            Text("mesh build avg: \(format(metrics.averageTerrainMeshBuildTimeMs)) ms")
            Text("draw calls total: \(metrics.metalDrawCallCount)")
            Text("passes t/p/pl/dbg: \(metrics.metalTerrainDrawCallCount) / \(metrics.metalPropDrawCallCount) / \(metrics.metalPlayerDrawCallCount) / \(metrics.metalDebugDrawCallCount)")
            Text("gpu buffers: \(metrics.metalBufferCount)")
            Text("terrain textures arrays/layers: \(metrics.metalTerrainTextureArrayCount) / \(metrics.metalTerrainTextureLayerCount)")
            Text("materials terrain / prop: \(metrics.metalVisibleTerrainMaterialCount) / \(metrics.metalVisiblePropMaterialCount)")
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
            Text("groundChunk x/y/z: \(format(metrics.currentGroundChunk))")
            Text("grounded: \(format(metrics.playerGrounded))")
            Text("terrainHeight: \(format(metrics.terrainHeightUnderPlayer))")
            Text("slope / max: \(format(metrics.slopeUnderPlayer)) / \(format(metrics.maxWalkableSlope))")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("CHUNKS")
            Text("active / visible / cached: \(metrics.activeChunkCount) / \(metrics.visibleChunkCount) / \(metrics.cachedChunkCount)")
            Text("generated: \(metrics.generatedChunkCount)")
            Text("triangles approx: \(metrics.approximateTriangleCount)")
            Text("props approx: \(metrics.approximatePropCount)")
            Text("drawn chunks / props: \(metrics.metalRenderedChunkCount) / \(metrics.metalRenderedPropCount)")
            Text("jobs queued / gen / ready: \(metrics.chunkJobsQueued) / \(metrics.chunkJobsGenerating) / \(metrics.chunksReadyForUpload)")
            Text("uploads this frame: \(metrics.chunkUploadsThisFrame)")
            Toggle("showChunkBounds", isOn: $metrics.showChunkBounds)
            Toggle("showChunkLabels", isOn: $metrics.showChunkLabels)

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("CAMERA")
            Text("movementMode: \(metrics.movementMode)")
            Text("yaw / pitch: \(formatDegrees(metrics.cameraYaw)) / \(formatDegrees(metrics.cameraPitch))")
            Text("distance: \(format(metrics.cameraDistance))")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("LIGHT")
            Text("sunDirection: \(formatVector(metrics.sunDirection))")
            Text("sunIntensity: \(format(metrics.sunIntensity))")
            Text("ambientIntensity: \(format(metrics.ambientIntensity))")
            Text("shadowsEnabled: \(format(metrics.shadowsEnabled))")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("INPUT")
            Text("controller: \(input.isGamepadConnected ? "Connected" : "Not connected")")
            Text("name: \(metrics.controllerName)")
            Text("moveX / moveY: \(format(input.moveX)) / \(format(input.moveY))")
            Text("lookX / lookY: \(format(input.lookX)) / \(format(input.lookY))")
            Text("jumpPressed: \(format(input.jumpPressed))")
            Text("primaryActionPressed: \(format(input.primaryActionPressed))")
            Text("secondaryActionPressed: \(format(input.secondaryActionPressed))")
            Text("sprintPressed: \(format(input.sprintPressed))")
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

    private func formatDegrees(_ radians: Float) -> String {
        "\(format(radians * 180 / Float.pi)) deg"
    }

    private func formatVector(_ vector: SIMD3<Float>) -> String {
        "\(format(vector.x)) / \(format(vector.y)) / \(format(vector.z))"
    }

    private func format(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    private func format(_ coordinate: ChunkCoordinate?) -> String {
        guard let coordinate else {
            return "n/a"
        }

        return "\(coordinate.x) / \(coordinate.y) / \(coordinate.z)"
    }
}
