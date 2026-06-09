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
            Text("Controller: \(input.isGamepadConnected ? "Connected" : "Not connected")")
            Text("Controller name: \(metrics.controllerName)")
            Divider().overlay(.white.opacity(0.35))
            Text("moveX / moveY: \(format(input.moveX)) / \(format(input.moveY))")
            Text("lookX / lookY: \(format(input.lookX)) / \(format(input.lookY))")
            Divider().overlay(.white.opacity(0.35))
            Text("jumpPressed: \(format(input.jumpPressed))")
            Text("primaryActionPressed: \(format(input.primaryActionPressed))")
            Text("secondaryActionPressed: \(format(input.secondaryActionPressed))")
            Text("sprintPressed: \(format(input.sprintPressed))")
            Divider().overlay(.white.opacity(0.35))
            Text("player x/y/z: \(format(metrics.playerPosition.x)) / \(format(metrics.playerPosition.y)) / \(format(metrics.playerPosition.z))")
            Text("terrainHeightUnderPlayer: \(format(metrics.terrainHeightUnderPlayer))")
            Text("playerY: \(format(metrics.playerPosition.y))")
            Text("slope: \(format(metrics.terrainSlopeUnderPlayer))")
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 360, alignment: .leading)
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
