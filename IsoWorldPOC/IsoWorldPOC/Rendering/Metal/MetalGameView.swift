//
//  MetalGameView.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import AppKit
import EngineCore
import MetalKit
import SwiftUI

struct MetalGameView: NSViewRepresentable {
    let debugMetrics: DebugMetrics
    let worldSession: WorldSession?
    let runtimeHandle: WorldRuntimeHandle?
    let publishesDebugTelemetry: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            debugMetrics: debugMetrics,
            worldSession: worldSession,
            runtimeHandle: runtimeHandle,
            publishesDebugTelemetry: publishesDebugTelemetry
        )
    }

    func makeNSView(context: Context) -> MTKView {
        let metalView = KeyboardControllableMTKView(frame: .zero, device: context.coordinator.renderer.device)
        metalView.delegate = context.coordinator.renderer
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearColor = context.coordinator.renderer.clearColor
        metalView.framebufferOnly = true
        context.coordinator.attach(to: metalView)
        context.coordinator.syncDebugState(from: debugMetrics)
        metalView.onKeyDown = { keyCode in
            context.coordinator.renderer.handleKeyDown(keyCode: keyCode)
            context.coordinator.requestDraw()
        }
        metalView.onKeyUp = { keyCode in
            context.coordinator.renderer.handleKeyUp(keyCode: keyCode)
            context.coordinator.requestDraw()
        }
        metalView.onKeyboardReset = {
            context.coordinator.renderer.resetKeyboard()
            context.coordinator.requestDraw()
        }
        metalView.onViewChanged = {
            context.coordinator.requestDraw()
        }
        return metalView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.syncDebugState(from: debugMetrics)
    }

    @MainActor
    final class Coordinator {
        let renderer: MetalRenderer
        private let cadenceController = DebugCadenceController()
        private var debugState: DebugViewportState?

        init(
            debugMetrics: DebugMetrics,
            worldSession: WorldSession?,
            runtimeHandle: WorldRuntimeHandle?,
            publishesDebugTelemetry: Bool
        ) {
            self.renderer = MetalRenderer(
                debugMetrics: debugMetrics,
                worldSession: worldSession,
                runtimeHandle: runtimeHandle,
                publishesDebugTelemetry: publishesDebugTelemetry
            )
        }

        func attach(to view: MTKView) {
            cadenceController.attach(view: view)
        }

        func syncDebugState(from metrics: DebugMetrics) {
            let nextState = DebugViewportState(metrics: metrics)
            guard nextState != debugState else {
                return
            }

            let policy = metrics.debugWorldRunMode.cadencePolicy
            cadenceController.apply(policy: policy)

            debugState = nextState
            cadenceController.requestDraw()
        }

        func requestDraw() {
            cadenceController.requestDraw()
        }
    }
}

private struct DebugViewportState: Equatable {
    let runMode: DebugWorldRunMode
    let showChunkBounds: Bool
    let renderTerrain: Bool
    let renderProps: Bool
    let renderPlayer: Bool
    let freezeSimulation: Bool
    let freezeChunkStreaming: Bool
    let forcedLODLevel: LODLevel?
    let pauseDebugMetricPublishing: Bool
    let showDebugDetails: Bool
    let terrainMaterialDebugMode: TerrainMaterialDebugMode
    let terrainSplatDebugLayerIndex: Int

    @MainActor
    init(metrics: DebugMetrics) {
        self.runMode = metrics.debugWorldRunMode
        self.showChunkBounds = metrics.showChunkBounds
        self.renderTerrain = metrics.renderTerrain
        self.renderProps = metrics.renderProps
        self.renderPlayer = metrics.renderPlayer
        self.freezeSimulation = metrics.freezeSimulation
        self.freezeChunkStreaming = metrics.freezeChunkStreaming
        self.forcedLODLevel = metrics.forcedLODLevel
        self.pauseDebugMetricPublishing = metrics.pauseDebugMetricPublishing
        self.showDebugDetails = metrics.showDebugDetails
        self.terrainMaterialDebugMode = metrics.terrainMaterialDebugMode
        self.terrainSplatDebugLayerIndex = metrics.terrainSplatDebugLayerIndex
    }
}

private final class KeyboardControllableMTKView: MTKView {
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    var onKeyboardReset: (() -> Void)?
    var onViewChanged: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        onViewChanged?()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        onViewChanged?()
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event.keyCode)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event.keyCode)
    }

    override func flagsChanged(with event: NSEvent) {
        let isPressed = event.modifierFlags.contains(.shift)

        if isPressed {
            onKeyDown?(event.keyCode)
        } else {
            onKeyUp?(event.keyCode)
        }
    }

    override func resignFirstResponder() -> Bool {
        onKeyboardReset?()
        return super.resignFirstResponder()
    }
}
