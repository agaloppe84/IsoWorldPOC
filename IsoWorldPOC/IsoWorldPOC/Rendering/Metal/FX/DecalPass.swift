//
//  DecalPass.swift
//  IsoWorldPOC
//
//  Created by Codex on 12/06/2026.
//

import EngineCore
import Metal
import simd

struct DecalPass: RenderPass {
    static let passDescriptor = RenderPassDescriptor(
        kind: .decals,
        name: "Decals",
        reads: [.fxDecals, .depth],
        writes: [.backbuffer],
        isOptional: true
    )

    let descriptor = Self.passDescriptor

    func encode(
        context: MetalFrameContext,
        renderEncoder: MTLRenderCommandEncoder
    ) -> MetalFrameDrawMetrics {
        guard !context.snapshot.fx.decals.isEmpty else {
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

        for decal in context.snapshot.fx.decals {
            let vertices = Self.vertices(for: decal)

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
            metrics.fxDecalsDrawn += 1
        }

        return metrics
    }

    private static func vertices(for decal: FXDecal) -> [MetalTerrainVertex] {
        let normal = normalized(decal.normal, fallback: SIMD3<Float>(0, 1, 0))
        let tangentBasis = abs(normal.y) > 0.92 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
        let tangent = normalized(simd_cross(tangentBasis, normal), fallback: SIMD3<Float>(1, 0, 0))
        let bitangent = normalized(simd_cross(normal, tangent), fallback: SIMD3<Float>(0, 0, 1))
        let rotation = decal.rotationRadians
        let rotatedTangent = tangent * cos(rotation) + bitangent * sin(rotation)
        let rotatedBitangent = -tangent * sin(rotation) + bitangent * cos(rotation)
        let center = decal.position + normal * 0.018
        let halfSize = max(decal.radius, 0.001)
        let color = simdColor(from: decal.displayColor)
        let material = MetalMaterialPayload.debug

        let bottomLeft = center - rotatedTangent * halfSize - rotatedBitangent * halfSize * 0.62
        let bottomRight = center + rotatedTangent * halfSize - rotatedBitangent * halfSize * 0.62
        let topRight = center + rotatedTangent * halfSize + rotatedBitangent * halfSize * 0.62
        let topLeft = center - rotatedTangent * halfSize + rotatedBitangent * halfSize * 0.62

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

func simdColor(from color: FXColor) -> SIMD4<Float> {
    SIMD4<Float>(color.red, color.green, color.blue, color.alpha)
}
