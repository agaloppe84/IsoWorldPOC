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
    let publishesDebugTelemetry: Bool
    let runtimeHandle: WorldRuntimeHandle?

    @StateObject private var debugMetrics: DebugMetrics

    init(
        showsDebugOverlay: Bool = true,
        initialRunMode: DebugWorldRunMode = .slowInspection,
        worldSession: WorldSession? = nil,
        runtimeHandle: WorldRuntimeHandle? = nil,
        publishesDebugTelemetry: Bool? = nil
    ) {
        self.showsDebugOverlay = showsDebugOverlay
        self.initialRunMode = initialRunMode
        self.worldSession = worldSession
        self.runtimeHandle = runtimeHandle
        let resolvedPublishesDebugTelemetry = publishesDebugTelemetry ?? showsDebugOverlay
        self.publishesDebugTelemetry = resolvedPublishesDebugTelemetry
        self._debugMetrics = StateObject(wrappedValue: DebugMetrics(
            debugWorldRunMode: initialRunMode,
            showChunkBounds: false,
            pauseDebugMetricPublishing: !resolvedPublishesDebugTelemetry
        ))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MetalGameView(
                debugMetrics: debugMetrics,
                worldSession: worldSession,
                runtimeHandle: runtimeHandle,
                publishesDebugTelemetry: publishesDebugTelemetry
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
