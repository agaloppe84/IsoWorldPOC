//
//  DebugSceneFactory.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import RealityKit
import simd

@MainActor
enum DebugSceneFactory {
    static func makePlayerEntity() -> Entity {
        let player = Entity()
        player.name = "Player"

        player.addChild(CharacterVisual.makeEntity())
        player.addChild(
            makePhysicsDebugBox(
                name: "PhysicsDebug_PlayerBody",
                size: [0.50, 1.00, 0.50],
                color: .init(calibratedRed: 1.0, green: 0.0, blue: 1.0, alpha: 1.0),
                center: [0, 0.50, 0]
            )
        )

        return player
    }

    static func makeReferenceFloor() -> Entity {
        let floor = Entity()
        floor.name = "DebugReferenceFloor"

        let floorMaterial = SimpleMaterial(
            color: .init(red: 0.12, green: 0.13, blue: 0.14, alpha: 1),
            roughness: 0.8,
            isMetallic: false
        )
        let floorEntity = ModelEntity(
            mesh: .generateBox(size: [14, 0.02, 14]),
            materials: [floorMaterial]
        )
        floorEntity.position = [0, -0.02, 0]
        floor.addChild(floorEntity)

        let minorLineMaterial = SimpleMaterial(
            color: .init(red: 0.32, green: 0.34, blue: 0.36, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )
        let majorLineMaterial = SimpleMaterial(
            color: .init(red: 0.50, green: 0.52, blue: 0.55, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )

        let halfLineCount = 7
        let length: Float = 14
        let minorThickness: Float = 0.018
        let majorThickness: Float = 0.034

        for index in -halfLineCount...halfLineCount {
            let offset = Float(index)
            let isMajorLine = index == 0 || index.isMultiple(of: 2)
            let thickness = isMajorLine ? majorThickness : minorThickness
            let material = isMajorLine ? majorLineMaterial : minorLineMaterial

            let xLine = ModelEntity(
                mesh: .generateBox(size: [length, 0.012, thickness]),
                materials: [material]
            )
            xLine.position = [0, 0.006, offset]
            floor.addChild(xLine)

            let zLine = ModelEntity(
                mesh: .generateBox(size: [thickness, 0.012, length]),
                materials: [material]
            )
            zLine.position = [offset, 0.007, 0]
            floor.addChild(zLine)
        }

        return floor
    }

    static func makeAxisMarkers() -> Entity {
        let axes = Entity()
        axes.name = "DebugAxisMarkers"

        let xMaterial = SimpleMaterial(color: .systemRed, roughness: 0.45, isMetallic: false)
        let zMaterial = SimpleMaterial(color: .systemBlue, roughness: 0.45, isMetallic: false)

        let xAxis = ModelEntity(
            mesh: .generateBox(size: [3.2, 0.06, 0.06]),
            materials: [xMaterial]
        )
        xAxis.position = [1.6, 0.06, 0]
        axes.addChild(xAxis)

        let zAxis = ModelEntity(
            mesh: .generateBox(size: [0.06, 0.06, 3.2]),
            materials: [zMaterial]
        )
        zAxis.position = [0, 0.08, 1.6]
        axes.addChild(zAxis)

        return axes
    }

    static func makeLighting(settings: SceneLightingSettings = .standard) -> Entity {
        let lighting = Entity()
        lighting.name = "SceneLighting"

        let sun = DirectionalLight()
        sun.name = "SunDirectionalLight"
        sun.light.color = .init(calibratedRed: 1.0, green: 0.94, blue: 0.82, alpha: 1.0)
        sun.light.intensity = settings.sunIntensity
        sun.look(
            at: .zero,
            from: -settings.sunDirection * 6,
            relativeTo: nil
        )

        if settings.shadowsEnabled {
            sun.shadow = DirectionalLightComponent.Shadow(
                maximumDistance: 24,
                depthBias: 1.2
            )
        }

        let fill = DirectionalLight()
        fill.name = "AmbientFillDirectionalLight"
        fill.light.color = .init(calibratedRed: 0.66, green: 0.76, blue: 1.0, alpha: 1.0)
        fill.light.intensity = settings.ambientIntensity
        fill.look(at: .zero, from: [-2, 3, -4], relativeTo: nil)

        lighting.addChild(sun)
        lighting.addChild(fill)

        return lighting
    }

    private static func makePhysicsDebugBox(
        name: String,
        size: SIMD3<Float>,
        color: NSColor,
        center: SIMD3<Float>
    ) -> Entity {
        let box = Entity()
        box.name = name
        box.position = center

        let material = SimpleMaterial(color: color, roughness: 0.35, isMetallic: false)
        let thickness: Float = 0.018
        let halfX = size.x * 0.5
        let halfY = size.y * 0.5
        let halfZ = size.z * 0.5

        for y in [-halfY, halfY] {
            for z in [-halfZ, halfZ] {
                box.addChild(
                    makeDebugBar(
                        size: [size.x, thickness, thickness],
                        position: [0, y, z],
                        material: material
                    )
                )
            }
        }

        for x in [-halfX, halfX] {
            for z in [-halfZ, halfZ] {
                box.addChild(
                    makeDebugBar(
                        size: [thickness, size.y, thickness],
                        position: [x, 0, z],
                        material: material
                    )
                )
            }
        }

        for x in [-halfX, halfX] {
            for y in [-halfY, halfY] {
                box.addChild(
                    makeDebugBar(
                        size: [thickness, thickness, size.z],
                        position: [x, y, 0],
                        material: material
                    )
                )
            }
        }

        return box
    }

    private static func makeDebugBar(
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let bar = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        bar.position = position

        return bar
    }
}
