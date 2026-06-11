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

    @StateObject private var debugMetrics = DebugMetrics()

    init(
        showsDebugOverlay: Bool = true,
        initialRunMode: DebugWorldRunMode = .slowInspection
    ) {
        self.showsDebugOverlay = showsDebugOverlay
        self.initialRunMode = initialRunMode
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MetalGameView(debugMetrics: debugMetrics)
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
