//
//  CharacterVisual.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import AppKit
import Foundation
import RealityKit

@MainActor
enum CharacterVisual {
    static func makeEntity() -> Entity {
        if let localModel = loadLocalModel() {
            return localModel
        }

        return makeProceduralHumanoid()
    }

    static func makeCapsuleFallbackEntity() -> Entity {
        let root = Entity()
        root.name = "CharacterVisual_CapsuleFallback"

        let material = SimpleMaterial(
            color: .systemYellow,
            roughness: 0.35,
            isMetallic: false
        )
        let capsule = ModelEntity(
            mesh: .generateBox(size: [0.42, 0.95, 0.42], cornerRadius: 0.2),
            materials: [material]
        )
        capsule.position = [0, 0.48, 0]

        root.addChild(capsule)
        return root
    }

    private static func loadLocalModel() -> Entity? {
        guard let url = firstLocalModelURL() else {
            return nil
        }

        do {
            let model = try Entity.load(contentsOf: url)
            let root = Entity()
            root.name = "CharacterVisual_LocalModel"
            model.name = "LocalCharacterModel_\(url.deletingPathExtension().lastPathComponent)"
            root.addChild(model)
            return root
        } catch {
            print("Failed to load local character model at \(url.path): \(error)")
            return makeCapsuleFallbackEntity()
        }
    }

    private static func firstLocalModelURL() -> URL? {
        let subdirectories: [String?] = [nil, "Assets/Models", "Models"]
        let preferredNames = ["Player", "Character", "Humanoid", "player", "character", "humanoid"]
        let extensions = ["usdz", "reality"]

        for subdirectory in subdirectories {
            for name in preferredNames {
                for fileExtension in extensions {
                    if let url = Bundle.main.url(
                        forResource: name,
                        withExtension: fileExtension,
                        subdirectory: subdirectory
                    ) {
                        return url
                    }
                }
            }

            for fileExtension in extensions {
                let urls = Bundle.main.urls(
                    forResourcesWithExtension: fileExtension,
                    subdirectory: subdirectory
                ) ?? []

                if let firstURL = urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first {
                    return firstURL
                }
            }
        }

        return nil
    }

    private static func makeProceduralHumanoid() -> Entity {
        let root = Entity()
        root.name = "CharacterVisual_ProceduralHumanoid"

        let bodyMaterial = SimpleMaterial(
            color: .init(calibratedRed: 0.16, green: 0.34, blue: 0.82, alpha: 1.0),
            roughness: 0.45,
            isMetallic: false
        )
        let headMaterial = SimpleMaterial(
            color: .init(calibratedRed: 0.86, green: 0.68, blue: 0.48, alpha: 1.0),
            roughness: 0.5,
            isMetallic: false
        )
        let limbMaterial = SimpleMaterial(
            color: .init(calibratedRed: 0.12, green: 0.18, blue: 0.28, alpha: 1.0),
            roughness: 0.55,
            isMetallic: false
        )
        let accentMaterial = SimpleMaterial(
            color: .systemYellow,
            roughness: 0.35,
            isMetallic: false
        )

        root.addChild(
            makePart(
                name: "CharacterBody",
                size: [0.34, 0.42, 0.22],
                cornerRadius: 0.08,
                position: [0, 0.55, 0],
                material: bodyMaterial
            )
        )
        root.addChild(
            makePart(
                name: "CharacterHead",
                size: [0.23, 0.23, 0.22],
                cornerRadius: 0.07,
                position: [0, 0.88, 0],
                material: headMaterial
            )
        )
        root.addChild(
            makePart(
                name: "CharacterFacingMarker",
                size: [0.16, 0.05, 0.025],
                cornerRadius: 0.01,
                position: [0, 0.64, -0.125],
                material: accentMaterial
            )
        )

        for side: Float in [-1, 1] {
            root.addChild(
                makePart(
                    name: side < 0 ? "CharacterLeftArm" : "CharacterRightArm",
                    size: [0.10, 0.36, 0.10],
                    cornerRadius: 0.04,
                    position: [side * 0.25, 0.51, 0],
                    material: limbMaterial
                )
            )
            root.addChild(
                makePart(
                    name: side < 0 ? "CharacterLeftLeg" : "CharacterRightLeg",
                    size: [0.11, 0.34, 0.11],
                    cornerRadius: 0.04,
                    position: [side * 0.09, 0.17, 0],
                    material: limbMaterial
                )
            )
        }

        return root
    }

    private static func makePart(
        name: String,
        size: SIMD3<Float>,
        cornerRadius: Float,
        position: SIMD3<Float>,
        material: SimpleMaterial
    ) -> ModelEntity {
        let entity = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: cornerRadius),
            materials: [material]
        )
        entity.name = name
        entity.position = position

        return entity
    }
}
