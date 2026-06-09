//
//  ProceduralTerrainFactory.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import EngineCore
import RealityKit
import simd

struct ProceduralTerrainChunk {
    let coordinate: ChunkCoordinate
    let biome: Biome
    let entity: Entity
    let sampler: TerrainSampler
    let propCount: Int
}

@MainActor
enum ProceduralTerrainFactory {
    static let horizontalScale: Float = 0.18
    static let verticalScale: Float = 0.08
    static let activeSeed = WorldSeed(12_345)
    static let chunkResolution = 64
    static let chunkWorldSize = Float(chunkResolution - 1) * horizontalScale
    static let triangleCountPerChunk = (chunkResolution - 1) * (chunkResolution - 1) * 2
    static let biomeSampler = BiomeSampler(seed: activeSeed)
    static let propGenerator = PropPlacementGenerator(seed: activeSeed, maxPropsPerChunk: 18)

    static func makeInitialChunk() -> ProceduralTerrainChunk? {
        makeChunk(coordinate: .origin)
    }

    static func makeChunk(coordinate: ChunkCoordinate) -> ProceduralTerrainChunk? {
        let terrainGeometry = coordinate.makeTerrainGeometry(
            seed: activeSeed,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        )
        let biome = biomeSampler.dominantBiome(
            for: coordinate,
            samplesPerChunk: chunkResolution
        )
        let propPlacements = propGenerator.placements(
            for: coordinate,
            biome: biome,
            samplesPerChunk: chunkResolution
        )

        do {
            let meshResource = try RealityKitTerrainAdapter.makeMeshResource(
                positions: terrainGeometry.positions.map { SIMD3<Float>($0.x, $0.y, $0.z) },
                normals: terrainGeometry.normals.map { SIMD3<Float>($0.x, $0.y, $0.z) },
                textureCoordinates: terrainGeometry.textureCoordinates.map { SIMD2<Float>($0.u, $0.v) },
                indices: terrainGeometry.indices
            )
            let material = SimpleMaterial(
                color: color(for: biome),
                roughness: 0.85,
                isMetallic: false
            )
            let entity = ModelEntity(mesh: meshResource, materials: [material])
            let halfExtent = chunkWorldSize * 0.5
            let originX = Float(coordinate.x) * chunkWorldSize - halfExtent
            let originZ = Float(coordinate.z) * chunkWorldSize - halfExtent
            let sampler = TerrainSampler(
                geometry: terrainGeometry,
                originX: originX,
                originZ: originZ
            )

            entity.name = "ProceduralTerrainChunk_\(coordinate.x)_\(coordinate.z)"
            entity.position = [originX, 0, originZ]

            for placement in propPlacements {
                entity.addChild(
                    makePropEntity(
                        for: placement,
                        sampler: sampler,
                        originX: originX,
                        originZ: originZ
                    )
                )
            }

            return ProceduralTerrainChunk(
                coordinate: coordinate,
                biome: biome,
                entity: entity,
                sampler: sampler,
                propCount: propPlacements.count
            )
        } catch {
            print("Failed to build procedural terrain chunk \(coordinate): \(error)")
            return nil
        }
    }

    private static func color(for biome: Biome) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(biome.placeholderColor.red),
            green: CGFloat(biome.placeholderColor.green),
            blue: CGFloat(biome.placeholderColor.blue),
            alpha: 1.0
        )
    }

    private static func makePropEntity(
        for placement: PropPlacement,
        sampler: TerrainSampler,
        originX: Float,
        originZ: Float
    ) -> Entity {
        let prop = Entity()
        let localX = placement.localX * horizontalScale
        let localZ = placement.localZ * horizontalScale
        let worldX = originX + localX
        let worldZ = originZ + localZ
        let terrainHeight = sampler.heightAt(x: worldX, z: worldZ)

        prop.name = "Prop_\(placement.type.rawValue)"
        prop.position = [localX, terrainHeight + 0.02, localZ]
        prop.orientation = simd_quatf(angle: placement.rotationRadians, axis: [0, 1, 0])
        prop.scale = [placement.scale, placement.scale, placement.scale]

        switch placement.type {
        case .rock:
            prop.addChild(makeRockEntity())
        case .treePlaceholder:
            prop.addChild(makeTreeEntity())
        case .crystalPlaceholder:
            prop.addChild(makeCrystalEntity())
        }

        return prop
    }

    private static func makeRockEntity() -> Entity {
        let material = SimpleMaterial(color: .systemGray, roughness: 0.9, isMetallic: false)
        let rock = ModelEntity(
            mesh: .generateBox(size: [0.32, 0.22, 0.28], cornerRadius: 0.06),
            materials: [material]
        )
        rock.position = [0, 0.11, 0]
        return rock
    }

    private static func makeTreeEntity() -> Entity {
        let tree = Entity()
        let trunkMaterial = SimpleMaterial(
            color: .init(red: 0.36, green: 0.22, blue: 0.12, alpha: 1),
            roughness: 0.8,
            isMetallic: false
        )
        let crownMaterial = SimpleMaterial(
            color: .init(red: 0.08, green: 0.40, blue: 0.16, alpha: 1),
            roughness: 0.75,
            isMetallic: false
        )
        let trunk = ModelEntity(
            mesh: .generateBox(size: [0.12, 0.45, 0.12], cornerRadius: 0.02),
            materials: [trunkMaterial]
        )
        let crown = ModelEntity(
            mesh: .generateBox(size: [0.45, 0.45, 0.45], cornerRadius: 0.08),
            materials: [crownMaterial]
        )

        trunk.position = [0, 0.225, 0]
        crown.position = [0, 0.62, 0]
        tree.addChild(trunk)
        tree.addChild(crown)

        return tree
    }

    private static func makeCrystalEntity() -> Entity {
        let material = SimpleMaterial(color: .systemCyan, roughness: 0.35, isMetallic: false)
        let crystal = ModelEntity(
            mesh: .generateBox(size: [0.20, 0.52, 0.20], cornerRadius: 0.03),
            materials: [material]
        )

        crystal.position = [0, 0.26, 0]
        crystal.orientation = simd_quatf(angle: Float.pi * 0.25, axis: [0, 0, 1])

        return crystal
    }
}
