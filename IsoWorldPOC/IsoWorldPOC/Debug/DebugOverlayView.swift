//
//  DebugOverlayView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import Foundation
import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject var metrics: DebugMetrics

    private var input: PlayerInputState {
        metrics.inputState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("PERF")
            Text("fps / frame: \(format(metrics.framesPerSecond)) / \(format(metrics.frameTimeMilliseconds)) ms")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("PLAYER")
            Text("position x/y/z: \(format(metrics.playerPosition.x)) / \(format(metrics.playerPosition.y)) / \(format(metrics.playerPosition.z))")
            Text("currentChunk x/y/z: \(metrics.currentChunk.x) / \(metrics.currentChunk.y) / \(metrics.currentChunk.z)")
            Text("terrainHeight: \(format(metrics.terrainHeightUnderPlayer))")
            Text("slope: \(format(metrics.terrainSlopeUnderPlayer))")

            Divider().overlay(.white.opacity(0.35))

            sectionTitle("CHUNKS")
            Text("active / cached: \(metrics.activeChunkCount) / \(metrics.cachedChunkCount)")
            Text("generated: \(metrics.generatedChunkCount)")
            Text("triangles approx: \(metrics.approximateTriangleCount)")
            Text("props approx: \(metrics.approximatePropCount)")

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

    private func format(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}
