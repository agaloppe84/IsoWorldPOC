//
//  MetalGameView.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import AppKit
import MetalKit
import SwiftUI

struct MetalGameView: NSViewRepresentable {
    let debugMetrics: DebugMetrics

    func makeCoordinator() -> Coordinator {
        Coordinator(debugMetrics: debugMetrics)
    }

    func makeNSView(context: Context) -> MTKView {
        let metalView = KeyboardControllableMTKView(frame: .zero, device: context.coordinator.renderer.device)
        metalView.delegate = context.coordinator.renderer
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearColor = context.coordinator.renderer.clearColor
        metalView.framebufferOnly = true
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.onKeyDown = { keyCode in
            context.coordinator.renderer.handleKeyDown(keyCode: keyCode)
        }
        metalView.onKeyUp = { keyCode in
            context.coordinator.renderer.handleKeyUp(keyCode: keyCode)
        }
        metalView.onKeyboardReset = {
            context.coordinator.renderer.resetKeyboard()
        }
        return metalView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}

    @MainActor
    final class Coordinator {
        let renderer: MetalRenderer

        init(debugMetrics: DebugMetrics) {
            self.renderer = MetalRenderer(debugMetrics: debugMetrics)
        }
    }
}

private final class KeyboardControllableMTKView: MTKView {
    var onKeyDown: ((UInt16) -> Void)?
    var onKeyUp: ((UInt16) -> Void)?
    var onKeyboardReset: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
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
