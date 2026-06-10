//
//  GameRootView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import SwiftUI

struct GameRootView: View {
    @StateObject private var debugMetrics = DebugMetrics()
    @State private var rendererMode = RendererMode.defaultMode

    var body: some View {
        ZStack(alignment: .topLeading) {
            gameView(for: rendererMode)
                .ignoresSafeArea()

            DebugOverlayView(metrics: debugMetrics)
                .padding(12)
        }
        .onAppear {
            debugMetrics.rendererMode = rendererMode
        }
        .onChange(of: rendererMode) { _, newMode in
            debugMetrics.rendererMode = newMode
        }
    }

    @ViewBuilder
    private func gameView(for mode: RendererMode) -> some View {
        switch mode {
        case .realityKit:
            RealityKitGameView(debugMetrics: debugMetrics)
        case .metalExperimental:
            MetalGameView(debugMetrics: debugMetrics)
        }
    }
}
