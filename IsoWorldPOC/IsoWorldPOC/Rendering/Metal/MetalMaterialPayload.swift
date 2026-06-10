//
//  MetalMaterialPayload.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import simd

enum MetalMaterialPayload {
    static let player = SIMD4<Float>(0.58, 10, 0, 0)
    static let debug = SIMD4<Float>(1.0, 20, 0, 0)

    static func terrain(_ material: TerrainMaterialDescriptor) -> SIMD4<Float> {
        SIMD4<Float>(
            clampedRoughness(material.roughness),
            Float(terrainKindID(material.kind)),
            clampedRoughness(material.roughness),
            0
        )
    }

    static func terrain(_ material: TerrainVertexMaterial) -> SIMD4<Float> {
        SIMD4<Float>(
            clampedRoughness(material.roughness),
            Float(terrainKindID(material.materialKind)),
            clampedRoughness(material.secondaryRoughness),
            min(max(material.blendWeight, 0), 1)
        )
    }

    static func prop(_ material: PropMaterialDescriptor) -> SIMD4<Float> {
        SIMD4<Float>(
            clampedRoughness(material.roughness),
            100,
            0,
            0
        )
    }

    private static func clampedRoughness(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func terrainKindID(_ kind: TerrainMaterialKind) -> Int {
        switch kind {
        case .grass:
            1
        case .rock:
            2
        case .dirt:
            3
        case .sand:
            4
        case .wetValley:
            5
        case .snow:
            6
        }
    }
}
