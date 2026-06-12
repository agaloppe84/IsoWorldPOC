//
//  UIMetalRenderer.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore
import Metal
import simd

struct UIQuadVertex {
    let position: SIMD2<Float>
    let color: SIMD4<Float>
}

struct UIViewportUniforms {
    let viewportSize: SIMD2<Float>
    let padding: SIMD2<Float> = .zero
}

final class UIMetalRenderer {
    static let maxInlineVertexBytes = 4_096

    private static let vertexBufferRingCount = 3

    private let device: MTLDevice?
    private let pipelineState: MTLRenderPipelineState?
    private let depthStencilState: MTLDepthStencilState?
    private var vertexBuffers: [MTLBuffer?]
    private var vertexBufferLengths: [Int]
    private var vertexBufferCursor = 0

    init(device: MTLDevice?) {
        self.device = device
        self.vertexBuffers = Array(repeating: nil, count: Self.vertexBufferRingCount)
        self.vertexBufferLengths = Array(repeating: 0, count: Self.vertexBufferRingCount)
        self.pipelineState = Self.makePipelineState(device: device)
        self.depthStencilState = Self.makeDepthStencilState(device: device)
    }

    func encode(
        snapshot: UIFrameSnapshot,
        drawableSize: SIMD2<Float>,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        let commands = makeDrawCommands(snapshot: snapshot, drawableSize: drawableSize)
        guard !commands.isEmpty, let pipelineState else {
            return .empty
        }

        let vertices = makeVertices(for: commands)
        guard !vertices.isEmpty else {
            return .empty
        }
        guard let vertexBuffer = makeVertexBuffer(containing: vertices) else {
            return .empty
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        if let depthStencilState {
            renderEncoder.setDepthStencilState(depthStencilState)
        }

        var uniforms = UIViewportUniforms(viewportSize: drawableSize)
        renderEncoder.setVertexBytes(
            &uniforms,
            length: MemoryLayout<UIViewportUniforms>.stride,
            index: 1
        )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(
            type: .triangle,
            vertexStart: 0,
            vertexCount: vertices.count
        )

        var metrics = MetalFrameDrawMetrics.empty
        metrics.hudDrawCalls = 1
        metrics.hudQuadsDrawn = commands.count
        return metrics
    }

    func makeDrawCommands(
        snapshot: UIFrameSnapshot,
        drawableSize: SIMD2<Float>
    ) -> [UIDrawCommand] {
        guard snapshot.hasVisibleHUD, drawableSize.x > 0, drawableSize.y > 0 else {
            return []
        }

        var commands: [UIDrawCommand] = []
        let theme = snapshot.theme
        let palette = theme.palette
        let margin: Float = 24
        let panelWidth: Float = min(max(drawableSize.x * 0.22, 190), 260)
        let statusPanel = UIFrameRect(x: margin, y: margin, width: panelWidth, height: 92)
        let worldPanel = UIFrameRect(
            x: max(drawableSize.x - panelWidth - margin, margin),
            y: margin,
            width: panelWidth,
            height: 78
        )

        appendPanel(statusPanel, theme: theme, commands: &commands, layer: 10)
        commands += UIAtlas.iconCommands(
            .health,
            originX: statusPanel.x + 14,
            originY: statusPanel.y + 18,
            size: 18,
            color: palette.danger,
            layer: 12
        )
        appendProgressBar(
            rect: UIFrameRect(x: statusPanel.x + 42, y: statusPanel.y + 18, width: statusPanel.width - 58, height: 12),
            progress: snapshot.hud.player.health,
            fill: palette.danger,
            palette: palette,
            commands: &commands,
            layer: 11
        )
        commands += UILabelRenderer.commands(
            text: "HP \(percent(snapshot.hud.player.health))",
            originX: statusPanel.x + 42,
            originY: statusPanel.y + 34,
            pixelHeight: theme.typography.labelPixelHeight,
            color: palette.textSecondary,
            layer: 12
        )
        commands += UIAtlas.iconCommands(
            .stamina,
            originX: statusPanel.x + 14,
            originY: statusPanel.y + 56,
            size: 18,
            color: palette.success,
            layer: 12
        )
        appendProgressBar(
            rect: UIFrameRect(x: statusPanel.x + 42, y: statusPanel.y + 56, width: statusPanel.width - 58, height: 12),
            progress: snapshot.hud.player.stamina,
            fill: palette.success,
            palette: palette,
            commands: &commands,
            layer: 11
        )
        commands += UILabelRenderer.commands(
            text: "ST \(percent(snapshot.hud.player.stamina))",
            originX: statusPanel.x + 42,
            originY: statusPanel.y + 72,
            pixelHeight: theme.typography.labelPixelHeight,
            color: palette.textSecondary,
            layer: 12
        )

        appendPanel(worldPanel, theme: theme, commands: &commands, layer: 10)
        commands += UIAtlas.iconCommands(
            .biome,
            originX: worldPanel.x + 14,
            originY: worldPanel.y + 18,
            size: 18,
            color: snapshot.hud.biome.tint,
            layer: 12
        )
        commands += UILabelRenderer.commands(
            text: compactLabel(snapshot.hud.biome.displayName),
            originX: worldPanel.x + 42,
            originY: worldPanel.y + 17,
            pixelHeight: theme.typography.labelPixelHeight,
            color: palette.textPrimary,
            layer: 12
        )
        commands += UIAtlas.iconCommands(
            .weather,
            originX: worldPanel.x + 14,
            originY: worldPanel.y + 47,
            size: 18,
            color: palette.warning,
            layer: 12
        )
        commands += UILabelRenderer.commands(
            text: snapshot.hud.weather.label,
            originX: worldPanel.x + 42,
            originY: worldPanel.y + 46,
            pixelHeight: theme.typography.labelPixelHeight,
            color: palette.textSecondary,
            layer: 12
        )

        if let terrainPrompt = snapshot.hud.terrainPrompt {
            let promptWidth = max(UILabelRenderer.measuredWidth(text: terrainPrompt, pixelHeight: 12) + 32, 96)
            let prompt = UIFrameRect(
                x: drawableSize.x * 0.5 - promptWidth * 0.5,
                y: drawableSize.y * 0.60,
                width: promptWidth,
                height: 30
            )
            appendPanel(prompt, theme: theme, commands: &commands, layer: 20)
            commands += UILabelRenderer.commands(
                text: terrainPrompt,
                originX: prompt.x + 16,
                originY: prompt.y + 8,
                pixelHeight: 12,
                color: palette.warning,
                layer: 22
            )
        }

        return UIDrawCommandBatcher.sorted(commands)
    }

    func makeVertices(for commands: [UIDrawCommand]) -> [UIQuadVertex] {
        commands.flatMap(vertices(for:))
    }

    static func vertexByteCount(vertexCount: Int) -> Int {
        MemoryLayout<UIQuadVertex>.stride * vertexCount
    }

    private func appendPanel(
        _ rect: UIFrameRect,
        theme: UITheme,
        commands: inout [UIDrawCommand],
        layer: Int
    ) {
        commands.append(UIDrawCommand(
            kind: .panel,
            rect: rect,
            color: theme.palette.surface,
            layer: layer,
            cornerRadius: theme.shapes.cornerRadius,
            materialOrder: 0
        ))
        let stroke = max(theme.shapes.strokeWidth, 1)
        commands += outlineCommands(
            rect: rect,
            stroke: stroke,
            color: theme.palette.outline,
            layer: layer + 1
        )
    }

    private func appendProgressBar(
        rect: UIFrameRect,
        progress: Float,
        fill: UIStyleColor,
        palette: UIThemePalette,
        commands: inout [UIDrawCommand],
        layer: Int
    ) {
        commands.append(UIDrawCommand(
            kind: .fill,
            rect: rect,
            color: palette.surfaceAlt,
            layer: layer,
            materialOrder: 1
        ))
        commands.append(UIDrawCommand(
            kind: .fill,
            rect: UIFrameRect(
                x: rect.x,
                y: rect.y,
                width: rect.width * min(max(progress, 0), 1),
                height: rect.height
            ),
            color: fill,
            layer: layer + 1,
            materialOrder: 2
        ))
    }

    private func outlineCommands(
        rect: UIFrameRect,
        stroke: Float,
        color: UIStyleColor,
        layer: Int
    ) -> [UIDrawCommand] {
        [
            UIFrameRect(x: rect.x, y: rect.y, width: rect.width, height: stroke),
            UIFrameRect(x: rect.x, y: rect.y + rect.height - stroke, width: rect.width, height: stroke),
            UIFrameRect(x: rect.x, y: rect.y, width: stroke, height: rect.height),
            UIFrameRect(x: rect.x + rect.width - stroke, y: rect.y, width: stroke, height: rect.height),
        ].map { outlineRect in
            UIDrawCommand(
                kind: .outline,
                rect: outlineRect,
                color: color,
                layer: layer,
                materialOrder: 1
            )
        }
    }

    private func vertices(for command: UIDrawCommand) -> [UIQuadVertex] {
        let rect = command.rect
        let color = simdColor(command.color)
        let minX = rect.x
        let minY = rect.y
        let maxX = rect.x + rect.width
        let maxY = rect.y + rect.height

        return [
            UIQuadVertex(position: SIMD2<Float>(minX, minY), color: color),
            UIQuadVertex(position: SIMD2<Float>(maxX, minY), color: color),
            UIQuadVertex(position: SIMD2<Float>(maxX, maxY), color: color),
            UIQuadVertex(position: SIMD2<Float>(minX, minY), color: color),
            UIQuadVertex(position: SIMD2<Float>(maxX, maxY), color: color),
            UIQuadVertex(position: SIMD2<Float>(minX, maxY), color: color),
        ]
    }

    private func simdColor(_ color: UIStyleColor) -> SIMD4<Float> {
        SIMD4<Float>(color.red, color.green, color.blue, color.alpha)
    }

    private func percent(_ value: Float) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    private func compactLabel(_ label: String) -> String {
        let filtered = label
            .uppercased()
            .filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
        let maxLength = 16

        guard filtered.count > maxLength else {
            return String(filtered)
        }

        return String(filtered.prefix(maxLength))
    }

    private func makeVertexBuffer(containing vertices: [UIQuadVertex]) -> MTLBuffer? {
        let byteCount = Self.vertexByteCount(vertexCount: vertices.count)
        guard byteCount > 0 else {
            return nil
        }

        let bufferIndex = vertexBufferCursor
        vertexBufferCursor = (vertexBufferCursor + 1) % Self.vertexBufferRingCount

        if vertexBuffers[bufferIndex] == nil || vertexBufferLengths[bufferIndex] < byteCount {
            vertexBufferLengths[bufferIndex] = Self.alignedBufferLength(for: byteCount)
            vertexBuffers[bufferIndex] = device?.makeBuffer(
                length: vertexBufferLengths[bufferIndex],
                options: .storageModeShared
            )
            vertexBuffers[bufferIndex]?.label = "IsoWorldHUDVertexBuffer.\(bufferIndex)"
        }

        guard let vertexBuffer = vertexBuffers[bufferIndex] else {
            return nil
        }

        vertices.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return
            }

            vertexBuffer.contents().copyMemory(
                from: UnsafeRawPointer(baseAddress),
                byteCount: byteCount
            )
        }

        return vertexBuffer
    }

    private static func alignedBufferLength(for byteCount: Int) -> Int {
        let alignment = 256
        return ((byteCount + alignment - 1) / alignment) * alignment
    }

    private static func makePipelineState(device: MTLDevice?) -> MTLRenderPipelineState? {
        guard
            let device,
            let library = device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "ui_vertex"),
            let fragmentFunction = library.makeFunction(name: "ui_fragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "IsoWorldUIOverlayPipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create UI pipeline state: \(error)")
            return nil
        }
    }

    private static func makeDepthStencilState(device: MTLDevice?) -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .always
        descriptor.isDepthWriteEnabled = false
        return device?.makeDepthStencilState(descriptor: descriptor)
    }
}
