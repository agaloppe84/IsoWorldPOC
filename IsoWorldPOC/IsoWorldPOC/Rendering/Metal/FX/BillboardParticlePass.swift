//
//  BillboardParticlePass.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore
import Metal
import simd

struct BillboardParticlePass: RenderPass {
    static let passDescriptor = RenderPassDescriptor(
        kind: .billboardParticles,
        name: "Billboard Particles",
        reads: [.fxParticles, .depth],
        writes: [.backbuffer],
        isOptional: true
    )

    let descriptor = Self.passDescriptor

    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        guard !context.snapshot.fx.particles.isEmpty else {
            return .empty
        }

        var uniforms = makeMetalUniforms(
            modelMatrix: matrix_identity_float4x4,
            viewProjectionMatrix: context.viewProjectionMatrix
        )
        renderEncoder.setVertexBytes(
            &uniforms,
            length: MemoryLayout<MetalTerrainUniforms>.stride,
            index: 1
        )

        var metrics = MetalFrameDrawMetrics.empty
        let cameraPosition = vector(from: context.snapshot.camera.position)

        for particle in context.snapshot.fx.particles {
            let vertices = Self.vertices(
                for: particle,
                cameraPosition: cameraPosition
            )

            vertices.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    return
                }

                renderEncoder.setVertexBytes(
                    UnsafeRawPointer(baseAddress),
                    length: MemoryLayout<MetalTerrainVertex>.stride * vertices.count,
                    index: 0
                )
            }
            renderEncoder.drawPrimitives(
                type: .triangle,
                vertexStart: 0,
                vertexCount: vertices.count
            )

            metrics.fxDrawCalls += 1
            metrics.fxParticlesDrawn += 1
        }

        return metrics
    }

    private static func vertices(
        for particle: FXBillboardParticle,
        cameraPosition: SIMD3<Float>
    ) -> [MetalTerrainVertex] {
        let center = particle.position
        let viewDirection = normalized(
            cameraPosition - center,
            fallback: SIMD3<Float>(0, 0, 1)
        )
        let worldUp = SIMD3<Float>(0, 1, 0)
        let right = normalized(
            simd_cross(worldUp, viewDirection),
            fallback: SIMD3<Float>(1, 0, 0)
        )
        let up = normalized(
            simd_cross(viewDirection, right),
            fallback: worldUp
        )
        let halfSize = max(particle.displaySize, 0.001) * 0.5
        let color = simdColor(from: particle.displayColor)
        let normal = viewDirection
        let material = MetalMaterialPayload.debug

        let bottomLeft = center - right * halfSize - up * halfSize
        let bottomRight = center + right * halfSize - up * halfSize
        let topRight = center + right * halfSize + up * halfSize
        let topLeft = center - right * halfSize + up * halfSize

        return [
            MetalTerrainVertex(position: bottomLeft, normal: normal, color: color, material: material),
            MetalTerrainVertex(position: bottomRight, normal: normal, color: color, material: material),
            MetalTerrainVertex(position: topRight, normal: normal, color: color, material: material),
            MetalTerrainVertex(position: bottomLeft, normal: normal, color: color, material: material),
            MetalTerrainVertex(position: topRight, normal: normal, color: color, material: material),
            MetalTerrainVertex(position: topLeft, normal: normal, color: color, material: material),
        ]
    }

    private static func normalized(
        _ vector: SIMD3<Float>,
        fallback: SIMD3<Float>
    ) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return fallback
        }

        return vector / length
    }
}
