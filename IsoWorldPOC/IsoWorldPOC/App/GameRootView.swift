//
//  GameRootView.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import SwiftUI

struct GameRootView: View {
    @StateObject private var debugMetrics = DebugMetrics()

    var body: some View {
        ZStack(alignment: .topLeading) {
            RealityKitGameView(debugMetrics: debugMetrics)
                .ignoresSafeArea()

            DebugOverlayView(metrics: debugMetrics)
                .padding(12)
        }
    }
}
