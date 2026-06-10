//
//  ChunkDebugVisualFactory.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import AppKit
import EngineCore
import RealityKit
import simd

enum ChunkDebugVisualState: Equatable {
    case current
    case active
    case generating
}

@MainActor
enum ChunkDebugVisualFactory {
    static func makeVisual(
        coordinate: ChunkCoordinate,
        state: ChunkDebugVisualState,
        showBounds: Bool,
        showLabels: Bool
    ) -> Entity {
        let root = Entity()
        root.name = "ChunkDebug_\(coordinate.x)_\(coordinate.z)"
        root.position = origin(for: coordinate)

        if showBounds {
            root.addChild(makeBounds(state: state))
        }

        if showLabels {
            root.addChild(makeLabel(coordinate: coordinate, state: state))
        }

        return root
    }

    private static func makeBounds(state: ChunkDebugVisualState) -> Entity {
        let bounds = Entity()
        bounds.name = "ChunkDebugBounds"

        let size = ProceduralTerrainFactory.chunkWorldSize
        let halfSize = size * 0.5
        let lineHeight = lineY(for: state)
        let thickness = lineThickness(for: state)
        let material = SimpleMaterial(
            color: color(for: state),
            roughness: 0.25,
            isMetallic: false
        )

        bounds.addChild(makeBar(size: [size, thickness, thickness], position: [halfSize, lineHeight, 0], material: material))
        bounds.addChild(makeBar(size: [size, thickness, thickness], position: [halfSize, lineHeight, size], material: material))
        bounds.addChild(makeBar(size: [thickness, thickness, size], position: [0, lineHeight, halfSize], material: material))
        bounds.addChild(makeBar(size: [thickness, thickness, size], position: [size, lineHeight, halfSize], material: material))

        return bounds
    }

    private static func makeLabel(coordinate: ChunkCoordinate, state: ChunkDebugVisualState) -> Entity {
        let label = "(\(coordinate.x),\(coordinate.z))"
        let textMesh = MeshResource.generateText(
            label,
            extrusionDepth: 0.008,
            font: .systemFont(ofSize: 0.28),
            containerFrame: CGRect(x: -0.8, y: -0.16, width: 1.6, height: 0.32),
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        let labelEntity = ModelEntity(
            mesh: textMesh,
            materials: [
                SimpleMaterial(
                    color: color(for: state),
                    roughness: 0.2,
                    isMetallic: false
                )
            ]
        )
        let halfSize = ProceduralTerrainFactory.chunkWorldSize * 0.5

        labelEntity.name = "ChunkDebugLabel"
        labelEntity.position = [halfSize, labelY(for: state), halfSize]
        labelEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

        return labelEntity
    }

    private static func origin(for coordinate: ChunkCoordinate) -> SIMD3<Float> {
        let size = ProceduralTerrainFactory.chunkWorldSize
        let halfExtent = size * 0.5

        return [
            Float(coordinate.x) * size - halfExtent,
            0,
            Float(coordinate.z) * size - halfExtent
        ]
    }

    private static func makeBar(
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let bar = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        bar.position = position

        return bar
    }

    private static func color(for state: ChunkDebugVisualState) -> NSColor {
        switch state {
        case .current:
            return .systemYellow
        case .active:
            return .systemCyan
        case .generating:
            return .systemOrange
        }
    }

    private static func lineY(for state: ChunkDebugVisualState) -> Float {
        switch state {
        case .current:
            return 0.10
        case .active:
            return 0.07
        case .generating:
            return 0.13
        }
    }

    private static func labelY(for state: ChunkDebugVisualState) -> Float {
        switch state {
        case .current:
            return 0.16
        case .active:
            return 0.13
        case .generating:
            return 0.19
        }
    }

    private static func lineThickness(for state: ChunkDebugVisualState) -> Float {
        switch state {
        case .current:
            return 0.045
        case .active:
            return 0.028
        case .generating:
            return 0.035
        }
    }
}
