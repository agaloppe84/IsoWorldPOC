//
//  RealityKitPropAdapter.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import AppKit
import EngineCore
import RealityKit
import simd

@MainActor
enum RealityKitPropAdapter {
    static func makeEntity(for variant: PropVariant) -> Entity {
        let root = Entity()
        root.name = "PropVariant_\(variant.archetypeID)_\(variant.placement.placementIndex)"

        for part in variant.geometry.parts {
            root.addChild(makeEntity(for: part, variant: variant))
        }

        return root
    }

    private static func makeEntity(for part: PropGeometryPart, variant: PropVariant) -> ModelEntity {
        let materialDescriptor = variant.material(for: part.materialSlot)
        let entity = ModelEntity(
            mesh: mesh(for: part),
            materials: [material(for: materialDescriptor)]
        )

        entity.position = simd(part.position)
        entity.orientation = orientation(from: part.rotationRadians)

        return entity
    }

    private static func mesh(for part: PropGeometryPart) -> MeshResource {
        let size = simd(part.size)

        switch part.shape {
        case .box:
            return .generateBox(size: size, cornerRadius: part.cornerRadius)
        case .capsule:
            return .generateBox(size: size, cornerRadius: min(part.cornerRadius, min(size.x, min(size.y, size.z)) * 0.5))
        case .cone:
            return .generateBox(size: size, cornerRadius: part.cornerRadius)
        }
    }

    private static func material(for descriptor: PropMaterialDescriptor) -> SimpleMaterial {
        SimpleMaterial(
            color: color(for: descriptor.color),
            roughness: MaterialScalarParameter(floatLiteral: descriptor.roughness),
            isMetallic: false
        )
    }

    private static func color(for color: BiomeColor) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: 1.0
        )
    }

    private static func orientation(from rotation: PropVector3) -> simd_quatf {
        let x = simd_quatf(angle: rotation.x, axis: [1, 0, 0])
        let y = simd_quatf(angle: rotation.y, axis: [0, 1, 0])
        let z = simd_quatf(angle: rotation.z, axis: [0, 0, 1])

        return z * y * x
    }

    private static func simd(_ vector: PropVector3) -> SIMD3<Float> {
        [vector.x, vector.y, vector.z]
    }
}
