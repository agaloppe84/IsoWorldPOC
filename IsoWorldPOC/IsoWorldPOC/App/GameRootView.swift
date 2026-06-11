//
//  GameRootView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import SwiftUI

struct GameRootView: View {
    let showsDebugOverlay: Bool
    let initialRunMode: DebugWorldRunMode
    let worldSession: WorldSession?

    @StateObject private var debugMetrics = DebugMetrics()

    init(
        showsDebugOverlay: Bool = true,
        initialRunMode: DebugWorldRunMode = .slowInspection,
        worldSession: WorldSession? = nil
    ) {
        self.showsDebugOverlay = showsDebugOverlay
        self.initialRunMode = initialRunMode
        self.worldSession = worldSession
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MetalGameView(
                debugMetrics: debugMetrics,
                worldSession: worldSession
            )
                .ignoresSafeArea()

            if showsDebugOverlay {
                DebugOverlayView(metrics: debugMetrics)
                    .padding(12)
            }
        }
        .onAppear {
            if debugMetrics.debugWorldRunMode != initialRunMode {
                debugMetrics.debugWorldRunMode = initialRunMode
            }

            debugMetrics.rendererMode = .activeMode
        }
    }
}
