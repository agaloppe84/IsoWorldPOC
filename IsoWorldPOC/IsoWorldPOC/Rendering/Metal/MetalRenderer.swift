//
//  MetalRenderer.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Foundation
import Metal
import MetalKit
import QuartzCore
import simd

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate, GameRenderer {
    let device: MTLDevice?
    let clearColor = MTLClearColor(red: 0.07, green: 0.10, blue: 0.14, alpha: 1.0)

    private let runtime: WorldRuntime
    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLRenderPipelineState?
    private let depthStencilState: MTLDepthStencilState?
    private let debugBoundsDepthStencilState: MTLDepthStencilState?
    private let debugMetrics: DebugMetrics
    private let terrainPass = MetalTerrainPass()
    private let propPass = MetalPropPass()
    private let playerPass = MetalPlayerPass()
    private let debugPass = MetalDebugPass()
    private var snapshot: RenderWorldSnapshot
    private var chunkBuffersByCoordinate: [ChunkCoordinate: MetalChunkBuffers] = [:]
    private var playerBuffers: MetalIndexedMeshBuffers?
    private var lastDrawMetrics = MetalFrameDrawMetrics.empty
    private var lastFrameTime = CACurrentMediaTime()
    private var smoothedFrameTime: Float?
    private var drawableSize = SIMD2<Float>(1, 1)
    private var chunkUploadsThisFrame = 0
    private var chunkUploadSampleCount = 0
    private var totalChunkUploadTimeMs: Float = 0

    init(debugMetrics: DebugMetrics) {
        let device = MTLCreateSystemDefaultDevice()

        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.pipelineState = MetalRenderer.makePipelineState(device: device)
        self.depthStencilState = MetalRenderer.makeDepthStencilState(device: device)
        self.debugBoundsDepthStencilState = MetalRenderer.makeDebugBoundsDepthStencilState(device: device)
        self.debugMetrics = debugMetrics
        self.runtime = WorldRuntime(
            debugOptions: RenderSnapshotDebugOptions(
                showChunkBounds: debugMetrics.showChunkBounds,
                showChunkLabels: debugMetrics.showChunkLabels,
                terrainMaterialDebugMode: debugMetrics.terrainMaterialDebugMode,
                terrainSplatDebugLayerIndex: debugMetrics.terrainSplatDebugLayerIndex
            )
        )
        self.snapshot = runtime.snapshot
        self.playerBuffers = MetalRenderer.makePlayerBuffers(device: device)

        super.init()

        syncBuffers(with: snapshot)
        updateDebugMetrics()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = SIMD2(
            max(Float(size.width), 1),
            max(Float(size.height), 1)
        )
    }

    func handleKeyDown(keyCode: UInt16) {
        runtime.handleKeyDown(keyCode: keyCode)
    }

    func handleKeyUp(keyCode: UInt16) {
        runtime.handleKeyUp(keyCode: keyCode)
    }

    func resetKeyboard() {
        runtime.resetKeyboard()
    }

    func update(deltaTime: Float) {
        snapshot = runtime.update(
            deltaTime: deltaTime,
            debugOptions: RenderSnapshotDebugOptions(
                showChunkBounds: debugMetrics.showChunkBounds,
                showChunkLabels: debugMetrics.showChunkLabels,
                terrainMaterialDebugMode: debugMetrics.terrainMaterialDebugMode,
                terrainSplatDebugLayerIndex: debugMetrics.terrainSplatDebugLayerIndex
            )
        )
    }

    func draw(in view: MTKView) {
        let deltaTime = updatePerformanceMetrics()
        update(deltaTime: deltaTime)

        chunkUploadsThisFrame = 0
        syncBuffers(with: snapshot)

        guard
            let commandQueue,
            let pipelineState,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        renderPassDescriptor.colorAttachments[0].clearColor = clearColor
        renderPassDescriptor.depthAttachment.clearDepth = 1.0

        renderEncoder.setRenderPipelineState(pipelineState)
        if let depthStencilState {
            renderEncoder.setDepthStencilState(depthStencilState)
        }

        let frameContext = MetalFrameContext(
            snapshot: snapshot,
            chunkBuffersByCoordinate: chunkBuffersByCoordinate,
            playerBuffers: playerBuffers,
            playerPosition: runtime.playerPosition,
            viewProjectionMatrix: makeViewProjectionMatrix(from: snapshot.camera)
        )
        var lightingUniforms = frameContext.lightingUniforms
        var debugUniforms = frameContext.debugUniforms
        renderEncoder.setVertexBytes(
            &lightingUniforms,
            length: MemoryLayout<MetalLightingUniforms>.stride,
            index: 2
        )
        renderEncoder.setVertexBytes(
            &debugUniforms,
            length: MemoryLayout<MetalRenderDebugUniforms>.stride,
            index: 3
        )

        var drawMetrics = MetalFrameDrawMetrics.empty
        drawMetrics.add(terrainPass.encode(context: frameContext, renderEncoder: renderEncoder))
        drawMetrics.add(propPass.encode(context: frameContext, renderEncoder: renderEncoder))
        drawMetrics.add(playerPass.encode(context: frameContext, renderEncoder: renderEncoder))
        drawMetrics.add(debugPass.encode(
            context: frameContext,
            renderEncoder: renderEncoder,
            depthStencilState: debugBoundsDepthStencilState
        ))
        lastDrawMetrics = drawMetrics

        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
        updateDebugMetrics()
    }

    private static func makePipelineState(device: MTLDevice?) -> MTLRenderPipelineState? {
        guard
            let device,
            let library = device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "terrain_vertex"),
            let fragmentFunction = library.makeFunction(name: "terrain_fragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "MetalExperimentalTerrainPipeline"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("Failed to create Metal pipeline state: \(error)")
            return nil
        }
    }

    private static func makeDepthStencilState(device: MTLDevice?) -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        return device?.makeDepthStencilState(descriptor: descriptor)
    }

    private static func makeDebugBoundsDepthStencilState(device: MTLDevice?) -> MTLDepthStencilState? {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .always
        descriptor.isDepthWriteEnabled = false
        return device?.makeDepthStencilState(descriptor: descriptor)
    }

    private static func makePlayerBuffers(device: MTLDevice?) -> MetalIndexedMeshBuffers? {
        MetalIndexedMeshBuffers(
            device: device,
            vertices: makeBoxVertices(
                size: SIMD3<Float>(0.38, 0.95, 0.38),
                color: SIMD4<Float>(1.0, 0.86, 0.08, 1.0),
                material: MetalMaterialPayload.player
            ),
            indices: boxIndices()
        )
    }

    private func syncBuffers(with snapshot: RenderWorldSnapshot) {
        let requiredCoordinates = Set(snapshot.chunks.map(\.coordinate))

        for loadedCoordinate in Array(chunkBuffersByCoordinate.keys) where !requiredCoordinates.contains(loadedCoordinate) {
            chunkBuffersByCoordinate.removeValue(forKey: loadedCoordinate)
        }

        for chunk in snapshot.chunks where chunkBuffersByCoordinate[chunk.coordinate] == nil {
            let uploadStart = currentTimeMilliseconds()
            guard let buffers = MetalChunkBuffers(device: device, renderChunk: chunk) else {
                continue
            }

            chunkBuffersByCoordinate[chunk.coordinate] = buffers
            chunkUploadsThisFrame += 1
            chunkUploadSampleCount += 1
            totalChunkUploadTimeMs += Float(currentTimeMilliseconds() - uploadStart)
        }
    }

    private func makeViewProjectionMatrix(from camera: CameraRenderState) -> matrix_float4x4 {
        let aspect = drawableSize.x / drawableSize.y
        let projection = matrixPerspectiveRightHanded(
            fieldOfViewY: camera.fieldOfViewDegrees * Float.pi / 180,
            aspect: aspect,
            nearZ: camera.nearClipDistance,
            farZ: camera.farClipDistance
        )
        let view = matrixLookAtRightHanded(
            eye: vector(from: camera.position),
            target: vector(from: camera.target),
            up: vector(from: camera.up)
        )

        return projection * view
    }

    private func updateDebugMetrics() {
        debugMetrics.rendererMode = .metal
        runtime.applyDebugMetrics(to: debugMetrics)
        debugMetrics.cachedChunkCount = chunkBuffersByCoordinate.count
        debugMetrics.averageChunkUploadMs = average(totalChunkUploadTimeMs, sampleCount: chunkUploadSampleCount)
        debugMetrics.chunkUploadsThisFrame = chunkUploadsThisFrame
        debugMetrics.metalDrawCallCount = lastDrawMetrics.totalDrawCalls
        debugMetrics.metalTerrainDrawCallCount = lastDrawMetrics.terrainDrawCalls
        debugMetrics.metalPropDrawCallCount = lastDrawMetrics.propDrawCalls
        debugMetrics.metalPlayerDrawCallCount = lastDrawMetrics.playerDrawCalls
        debugMetrics.metalDebugDrawCallCount = lastDrawMetrics.debugDrawCalls
        debugMetrics.metalRenderedChunkCount = lastDrawMetrics.terrainChunksDrawn
        debugMetrics.metalRenderedPropCount = lastDrawMetrics.propsDrawn
        debugMetrics.metalBufferCount = metalBufferCount
        debugMetrics.metalVisibleTerrainMaterialCount = visibleTerrainMaterialCount
        debugMetrics.metalVisiblePropMaterialCount = visiblePropMaterialCount
    }

    private var metalBufferCount: Int {
        let playerBufferCount = playerBuffers?.bufferCount ?? 0

        return chunkBuffersByCoordinate.values.reduce(playerBufferCount) { total, buffers in
            total + buffers.bufferCount
        }
    }

    private var visibleTerrainMaterialCount: Int {
        Set(snapshot.chunks.filter(\.isVisible).flatMap { chunk in
            if chunk.terrainVertexMaterials.isEmpty {
                [chunk.terrainMaterial.identifier]
            } else {
                chunk.terrainVertexMaterials.flatMap { material in
                    material.splat.layers.map(\.materialIdentifier)
                }
            }
        }).count
    }

    private var visiblePropMaterialCount: Int {
        Set(snapshot.chunks.filter(\.isVisible).flatMap { chunk in
            chunk.props.filter(\.isVisible).flatMap { prop in
                [
                    prop.variant.primaryMaterial.identifier,
                    prop.variant.secondaryMaterial.identifier,
                    prop.variant.accentMaterial.identifier,
                ]
            }
        }).count
    }

    private func updatePerformanceMetrics() -> Float {
        let now = CACurrentMediaTime()
        let deltaTime = Float(now - lastFrameTime)
        lastFrameTime = now

        guard deltaTime > 0 else {
            return 0
        }

        if let previous = smoothedFrameTime {
            smoothedFrameTime = previous * 0.9 + deltaTime * 0.1
        } else {
            smoothedFrameTime = deltaTime
        }

        guard let smoothedFrameTime else {
            return min(deltaTime, 1.0 / 15.0)
        }

        debugMetrics.frameTimeMilliseconds = smoothedFrameTime * 1_000
        debugMetrics.framesPerSecond = 1 / smoothedFrameTime

        return min(deltaTime, 1.0 / 15.0)
    }

    private func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }

    private func average(_ total: Float, sampleCount: Int) -> Float? {
        guard sampleCount > 0 else {
            return nil
        }

        return total / Float(sampleCount)
    }
}

struct MetalIndexedMeshBuffers {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int

    var bufferCount: Int {
        2
    }

    init?(
        device: MTLDevice?,
        vertices: [MetalTerrainVertex],
        indices: [UInt32]
    ) {
        guard
            let device,
            let vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: MemoryLayout<MetalTerrainVertex>.stride * vertices.count,
                options: []
            ),
            let indexBuffer = device.makeBuffer(
                bytes: indices,
                length: MemoryLayout<UInt32>.stride * indices.count,
                options: []
            )
        else {
            return nil
        }

        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        self.indexCount = indices.count
    }
}

struct MetalChunkBuffers {
    let renderChunk: RenderChunk
    let terrainVertexBuffer: MTLBuffer
    let terrainIndexBuffer: MTLBuffer
    let terrainIndexCount: Int
    let propVertexBuffer: MTLBuffer?
    let propIndexBuffer: MTLBuffer?
    let propIndexCount: Int
    let debugBoundsLineVertexBuffer: MTLBuffer?
    let debugBoundsLineVertexCount: Int

    var bufferCount: Int {
        2 +
            (propVertexBuffer == nil ? 0 : 1) +
            (propIndexBuffer == nil ? 0 : 1) +
            (debugBoundsLineVertexBuffer == nil ? 0 : 1)
    }

    init?(device: MTLDevice?, renderChunk: RenderChunk) {
        let geometry = renderChunk.terrainGeometry
        let terrainVertices = Self.terrainVertices(
            from: geometry,
            fallbackMaterial: renderChunk.terrainMaterial,
            vertexMaterials: renderChunk.terrainVertexMaterials
        )
        let propMesh = Self.propMesh(for: renderChunk)
        let debugLineVertices = Self.debugBoundsLineVertices(for: renderChunk)

        guard
            let device,
            terrainVertices.count == geometry.positions.count,
            let terrainVertexBuffer = device.makeBuffer(
                bytes: terrainVertices,
                length: MemoryLayout<MetalTerrainVertex>.stride * terrainVertices.count,
                options: []
            ),
            let terrainIndexBuffer = device.makeBuffer(
                bytes: geometry.indices,
                length: MemoryLayout<UInt32>.stride * geometry.indices.count,
                options: []
            )
        else {
            return nil
        }

        self.renderChunk = renderChunk
        self.terrainVertexBuffer = terrainVertexBuffer
        self.terrainIndexBuffer = terrainIndexBuffer
        self.terrainIndexCount = geometry.indices.count
        self.propVertexBuffer = makeBuffer(device: device, values: propMesh.vertices)
        self.propIndexBuffer = makeBuffer(device: device, values: propMesh.indices)
        self.propIndexCount = propMesh.indices.count
        self.debugBoundsLineVertexBuffer = device.makeBuffer(
            bytes: debugLineVertices,
            length: MemoryLayout<MetalTerrainVertex>.stride * debugLineVertices.count,
            options: []
        )
        self.debugBoundsLineVertexCount = debugLineVertices.count
    }

    private static func terrainVertices(
        from geometry: TerrainGeometryBuffers,
        fallbackMaterial: TerrainMaterialDescriptor,
        vertexMaterials: [TerrainVertexMaterial]
    ) -> [MetalTerrainVertex] {
        let hasPerVertexMaterials = vertexMaterials.count == geometry.positions.count
        let fallbackColor = color(from: fallbackMaterial.baseColor)
        let fallbackPayload = MetalMaterialPayload.terrain(fallbackMaterial)
        let fallbackSplatWeights = MetalMaterialPayload.terrainSplatWeights(fallbackMaterial)
        let fallbackSplatMaterialIDs = MetalMaterialPayload.terrainSplatMaterialIDs(fallbackMaterial)

        return zip(geometry.positions, geometry.normals).enumerated().map { index, pair in
            let position = pair.0
            let normal = pair.1
            let vertexMaterial = hasPerVertexMaterials ? vertexMaterials[index] : nil
            let primaryColor = vertexMaterial.map { color(from: $0.baseColor) } ?? fallbackColor
            let secondaryColor = vertexMaterial.map { color(from: $0.secondaryBaseColor) } ?? fallbackColor
            let splatWeights = vertexMaterial.map(MetalMaterialPayload.terrainSplatWeights) ?? fallbackSplatWeights
            let splatMaterialIDs = vertexMaterial.map(MetalMaterialPayload.terrainSplatMaterialIDs) ?? fallbackSplatMaterialIDs

            return MetalTerrainVertex(
                position: SIMD3<Float>(position.x, position.y, position.z),
                normal: SIMD3<Float>(normal.x, normal.y, normal.z),
                color: primaryColor,
                material: vertexMaterial.map(MetalMaterialPayload.terrain) ?? fallbackPayload,
                secondaryColor: secondaryColor,
                splatWeights: splatWeights,
                splatMaterialIDs: splatMaterialIDs
            )
        }
    }

    private static func propMesh(for chunk: RenderChunk) -> (
        vertices: [MetalTerrainVertex],
        indices: [UInt32]
    ) {
        var vertices: [MetalTerrainVertex] = []
        var indices: [UInt32] = []

        for prop in chunk.props where prop.isVisible {
            let propPosition = vector(from: prop.worldPosition) - vector(from: chunk.origin)

            for part in prop.variant.geometry.parts {
                let baseIndex = UInt32(vertices.count)
                let material = prop.variant.material(for: part.materialSlot)
                let color = propColor(for: material)
                let partVertices = centeredBoxVertices(
                    size: vector(from: part.size),
                    color: color,
                    material: MetalMaterialPayload.prop(material)
                ).map { vertex in
                    transformedPropVertex(
                        vertex,
                        part: part,
                        propPosition: propPosition,
                        propRotationY: prop.rotationRadians
                    )
                }

                vertices.append(contentsOf: partVertices)
                indices.append(contentsOf: boxIndices().map { baseIndex + $0 })
            }
        }

        return (vertices, indices)
    }

    private static func transformedPropVertex(
        _ vertex: MetalTerrainVertex,
        part: PropGeometryPart,
        propPosition: SIMD3<Float>,
        propRotationY: Float
    ) -> MetalTerrainVertex {
        let partRotation = matrixRotationXYZ(vector(from: part.rotationRadians))
        let propRotation = matrixRotationY(propRotationY)
        let partOffset = vector(from: part.position)
        let rotatedPosition = transformPoint(vertex.position, by: partRotation) + partOffset
        let finalPosition = transformPoint(rotatedPosition, by: propRotation) + propPosition
        let finalNormal = simd_normalize(transformDirection(
            transformDirection(vertex.normal, by: partRotation),
            by: propRotation
        ))

        return MetalTerrainVertex(
            position: finalPosition,
            normal: finalNormal,
            color: vertex.color,
            material: vertex.material,
            secondaryColor: vertex.secondaryColor,
            splatWeights: vertex.splatWeights,
            splatMaterialIDs: vertex.splatMaterialIDs
        )
    }

    private static func centeredBoxVertices(
        size: SIMD3<Float>,
        color: SIMD4<Float>,
        material: SIMD4<Float>
    ) -> [MetalTerrainVertex] {
        let halfX = size.x * 0.5
        let halfY = size.y * 0.5
        let halfZ = size.z * 0.5
        let frontNormal = SIMD3<Float>(0, 0, 1)
        let backNormal = SIMD3<Float>(0, 0, -1)
        let leftNormal = SIMD3<Float>(-1, 0, 0)
        let rightNormal = SIMD3<Float>(1, 0, 0)
        let topNormal = SIMD3<Float>(0, 1, 0)
        let bottomNormal = SIMD3<Float>(0, -1, 0)

        return [
            MetalTerrainVertex(position: [-halfX, -halfY, halfZ], normal: frontNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, -halfY, halfZ], normal: frontNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, halfY, halfZ], normal: frontNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, halfY, halfZ], normal: frontNormal, color: color, material: material),

            MetalTerrainVertex(position: [halfX, -halfY, -halfZ], normal: backNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, -halfY, -halfZ], normal: backNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, halfY, -halfZ], normal: backNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, halfY, -halfZ], normal: backNormal, color: color, material: material),

            MetalTerrainVertex(position: [-halfX, -halfY, -halfZ], normal: leftNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, -halfY, halfZ], normal: leftNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, halfY, halfZ], normal: leftNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, halfY, -halfZ], normal: leftNormal, color: color, material: material),

            MetalTerrainVertex(position: [halfX, -halfY, halfZ], normal: rightNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, -halfY, -halfZ], normal: rightNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, halfY, -halfZ], normal: rightNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, halfY, halfZ], normal: rightNormal, color: color, material: material),

            MetalTerrainVertex(position: [-halfX, halfY, halfZ], normal: topNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, halfY, halfZ], normal: topNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, halfY, -halfZ], normal: topNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, halfY, -halfZ], normal: topNormal, color: color, material: material),

            MetalTerrainVertex(position: [-halfX, -halfY, -halfZ], normal: bottomNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, -halfY, -halfZ], normal: bottomNormal, color: color, material: material),
            MetalTerrainVertex(position: [halfX, -halfY, halfZ], normal: bottomNormal, color: color, material: material),
            MetalTerrainVertex(position: [-halfX, -halfY, halfZ], normal: bottomNormal, color: color, material: material),
        ]
    }

    private static func propColor(for material: PropMaterialDescriptor) -> SIMD4<Float> {
        color(from: material.color)
    }

    private static func color(from color: BiomeColor) -> SIMD4<Float> {
        SIMD4<Float>(color.red, color.green, color.blue, 1)
    }

    private static func debugBoundsLineVertices(for chunk: RenderChunk) -> [MetalTerrainVertex] {
        guard let bounds = chunk.debugBounds else {
            return []
        }

        let geometry = chunk.terrainGeometry
        let maxX = geometry.positions.map(\.x).max() ?? bounds.size.x
        let maxZ = geometry.positions.map(\.z).max() ?? bounds.size.z
        let minY = (geometry.positions.map(\.y).min() ?? 0) + 0.04
        let maxY = (geometry.positions.map(\.y).max() ?? bounds.size.y) + 0.18
        let color = debugBoundsColor(for: bounds.state)
        let normal = SIMD3<Float>(0, 1, 0)

        let p000 = SIMD3<Float>(0, minY, 0)
        let p100 = SIMD3<Float>(maxX, minY, 0)
        let p110 = SIMD3<Float>(maxX, minY, maxZ)
        let p010 = SIMD3<Float>(0, minY, maxZ)
        let p001 = SIMD3<Float>(0, maxY, 0)
        let p101 = SIMD3<Float>(maxX, maxY, 0)
        let p111 = SIMD3<Float>(maxX, maxY, maxZ)
        let p011 = SIMD3<Float>(0, maxY, maxZ)
        let linePositions = [
            p000, p100, p100, p110, p110, p010, p010, p000,
            p001, p101, p101, p111, p111, p011, p011, p001,
            p000, p001, p100, p101, p110, p111, p010, p011,
        ]

        return linePositions.map { position in
            MetalTerrainVertex(
                position: position,
                normal: normal,
                color: color,
                material: MetalMaterialPayload.debug
            )
        }
    }

    private static func debugBoundsColor(for state: RenderChunkDebugState) -> SIMD4<Float> {
        switch state {
        case .current:
            SIMD4<Float>(1.0, 0.92, 0.12, 1.0)
        case .active:
            SIMD4<Float>(0.15, 0.85, 1.0, 1.0)
        case .generating:
            SIMD4<Float>(1.0, 0.55, 0.10, 1.0)
        case .inactive:
            SIMD4<Float>(0.55, 0.55, 0.55, 1.0)
        }
    }
}

struct MetalTerrainVertex {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let color: SIMD4<Float>
    let secondaryColor: SIMD4<Float>
    let material: SIMD4<Float>
    let splatWeights: SIMD4<Float>
    let splatMaterialIDs: SIMD4<Float>

    init(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        color: SIMD4<Float>,
        material: SIMD4<Float>,
        secondaryColor: SIMD4<Float>? = nil,
        splatWeights: SIMD4<Float> = SIMD4<Float>(1, 0, 0, 0),
        splatMaterialIDs: SIMD4<Float> = SIMD4<Float>(0, 0, 0, 0)
    ) {
        self.position = position
        self.normal = normal
        self.color = color
        self.secondaryColor = secondaryColor ?? color
        self.material = material
        self.splatWeights = splatWeights
        self.splatMaterialIDs = splatMaterialIDs
    }
}

private func makeBoxVertices(
    size: SIMD3<Float>,
    color: SIMD4<Float>,
    material: SIMD4<Float>
) -> [MetalTerrainVertex] {
    let halfX = size.x * 0.5
    let halfZ = size.z * 0.5
    let minY: Float = 0
    let maxY = size.y

    let frontNormal = SIMD3<Float>(0, 0, 1)
    let backNormal = SIMD3<Float>(0, 0, -1)
    let leftNormal = SIMD3<Float>(-1, 0, 0)
    let rightNormal = SIMD3<Float>(1, 0, 0)
    let topNormal = SIMD3<Float>(0, 1, 0)
    let bottomNormal = SIMD3<Float>(0, -1, 0)

    return [
        MetalTerrainVertex(position: [-halfX, minY, halfZ], normal: frontNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, minY, halfZ], normal: frontNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, maxY, halfZ], normal: frontNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, maxY, halfZ], normal: frontNormal, color: color, material: material),

        MetalTerrainVertex(position: [halfX, minY, -halfZ], normal: backNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, minY, -halfZ], normal: backNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, maxY, -halfZ], normal: backNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, maxY, -halfZ], normal: backNormal, color: color, material: material),

        MetalTerrainVertex(position: [-halfX, minY, -halfZ], normal: leftNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, minY, halfZ], normal: leftNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, maxY, halfZ], normal: leftNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, maxY, -halfZ], normal: leftNormal, color: color, material: material),

        MetalTerrainVertex(position: [halfX, minY, halfZ], normal: rightNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, minY, -halfZ], normal: rightNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, maxY, -halfZ], normal: rightNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, maxY, halfZ], normal: rightNormal, color: color, material: material),

        MetalTerrainVertex(position: [-halfX, maxY, halfZ], normal: topNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, maxY, halfZ], normal: topNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, maxY, -halfZ], normal: topNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, maxY, -halfZ], normal: topNormal, color: color, material: material),

        MetalTerrainVertex(position: [-halfX, minY, -halfZ], normal: bottomNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, minY, -halfZ], normal: bottomNormal, color: color, material: material),
        MetalTerrainVertex(position: [halfX, minY, halfZ], normal: bottomNormal, color: color, material: material),
        MetalTerrainVertex(position: [-halfX, minY, halfZ], normal: bottomNormal, color: color, material: material),
    ]
}

private func boxIndices() -> [UInt32] {
    var indices: [UInt32] = []
    indices.reserveCapacity(36)

    for faceStart in stride(from: UInt32(0), to: 24, by: 4) {
        indices.append(contentsOf: [
            faceStart,
            faceStart + 1,
            faceStart + 2,
            faceStart,
            faceStart + 2,
            faceStart + 3,
        ])
    }

    return indices
}

struct MetalTerrainUniforms {
    let modelViewProjectionMatrix: matrix_float4x4
    let modelMatrix: matrix_float4x4
}

private func makeBuffer<T>(
    device: MTLDevice,
    values: [T]
) -> MTLBuffer? {
    guard !values.isEmpty else {
        return nil
    }

    return values.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
            return nil
        }

        return device.makeBuffer(
            bytes: baseAddress,
            length: bytes.count,
            options: []
        )
    }
}

func vector(from position: WorldPosition) -> SIMD3<Float> {
    SIMD3<Float>(position.x, position.y, position.z)
}

func vector(from vector: PropVector3) -> SIMD3<Float> {
    SIMD3<Float>(vector.x, vector.y, vector.z)
}

private func transformPoint(
    _ point: SIMD3<Float>,
    by matrix: matrix_float4x4
) -> SIMD3<Float> {
    let transformed = matrix * SIMD4<Float>(point.x, point.y, point.z, 1)
    return SIMD3<Float>(transformed.x, transformed.y, transformed.z)
}

private func transformDirection(
    _ direction: SIMD3<Float>,
    by matrix: matrix_float4x4
) -> SIMD3<Float> {
    let transformed = matrix * SIMD4<Float>(direction.x, direction.y, direction.z, 0)
    return SIMD3<Float>(transformed.x, transformed.y, transformed.z)
}

func matrixTranslation(_ translation: SIMD3<Float>) -> matrix_float4x4 {
    matrix_float4x4(columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    ))
}

private func matrixRotationXYZ(_ rotation: SIMD3<Float>) -> matrix_float4x4 {
    matrixRotationZ(rotation.z) * matrixRotationY(rotation.y) * matrixRotationX(rotation.x)
}

private func matrixRotationX(_ angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)

    return matrix_float4x4(columns: (
        SIMD4<Float>(1, 0, 0, 0),
        SIMD4<Float>(0, c, s, 0),
        SIMD4<Float>(0, -s, c, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ))
}

private func matrixRotationY(_ angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)

    return matrix_float4x4(columns: (
        SIMD4<Float>(c, 0, -s, 0),
        SIMD4<Float>(0, 1, 0, 0),
        SIMD4<Float>(s, 0, c, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ))
}

private func matrixRotationZ(_ angle: Float) -> matrix_float4x4 {
    let c = cos(angle)
    let s = sin(angle)

    return matrix_float4x4(columns: (
        SIMD4<Float>(c, s, 0, 0),
        SIMD4<Float>(-s, c, 0, 0),
        SIMD4<Float>(0, 0, 1, 0),
        SIMD4<Float>(0, 0, 0, 1)
    ))
}

private func matrixPerspectiveRightHanded(
    fieldOfViewY: Float,
    aspect: Float,
    nearZ: Float,
    farZ: Float
) -> matrix_float4x4 {
    let yScale = 1 / tan(fieldOfViewY * 0.5)
    let xScale = yScale / aspect
    let zRange = farZ - nearZ
    let zScale = -farZ / zRange
    let wzScale = -(farZ * nearZ) / zRange

    return matrix_float4x4(columns: (
        SIMD4<Float>(xScale, 0, 0, 0),
        SIMD4<Float>(0, yScale, 0, 0),
        SIMD4<Float>(0, 0, zScale, -1),
        SIMD4<Float>(0, 0, wzScale, 0)
    ))
}

private func matrixLookAtRightHanded(
    eye: SIMD3<Float>,
    target: SIMD3<Float>,
    up: SIMD3<Float>
) -> matrix_float4x4 {
    let zAxis = simd_normalize(eye - target)
    let xAxis = simd_normalize(simd_cross(up, zAxis))
    let yAxis = simd_cross(zAxis, xAxis)

    return matrix_float4x4(columns: (
        SIMD4<Float>(xAxis.x, yAxis.x, zAxis.x, 0),
        SIMD4<Float>(xAxis.y, yAxis.y, zAxis.y, 0),
        SIMD4<Float>(xAxis.z, yAxis.z, zAxis.z, 0),
        SIMD4<Float>(
            -simd_dot(xAxis, eye),
            -simd_dot(yAxis, eye),
            -simd_dot(zAxis, eye),
            1
        )
    ))
}
