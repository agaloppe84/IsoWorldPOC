//
//  ProceduralTerrainFactory.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import EngineCore
import Foundation
import RealityKit
import simd

struct ProceduralChunkBuildMetrics {
    let chunkGenerationTimeMs: Float
    let terrainMeshBuildTimeMs: Float
}

struct ProceduralTerrainChunk {
    let coordinate: ChunkCoordinate
    let biome: Biome
    let entity: Entity
    let sampler: TerrainSampler
    let propCount: Int
    let buildMetrics: ProceduralChunkBuildMetrics
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
        let chunkBuildStart = currentTimeMilliseconds()
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
            let meshBuildStart = currentTimeMilliseconds()
            let meshResource = try RealityKitTerrainAdapter.makeMeshResource(
                positions: terrainGeometry.positions.map { SIMD3<Float>($0.x, $0.y, $0.z) },
                normals: terrainGeometry.normals.map { SIMD3<Float>($0.x, $0.y, $0.z) },
                textureCoordinates: terrainGeometry.textureCoordinates.map { SIMD2<Float>($0.u, $0.v) },
                indices: terrainGeometry.indices
            )
            let terrainMeshBuildTimeMs = Float(currentTimeMilliseconds() - meshBuildStart)
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

            let buildMetrics = ProceduralChunkBuildMetrics(
                chunkGenerationTimeMs: Float(currentTimeMilliseconds() - chunkBuildStart),
                terrainMeshBuildTimeMs: terrainMeshBuildTimeMs
            )

            return ProceduralTerrainChunk(
                coordinate: coordinate,
                biome: biome,
                entity: entity,
                sampler: sampler,
                propCount: propPlacements.count,
                buildMetrics: buildMetrics
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

        let debugSize = physicsDebugSize(for: placement.type)
        prop.addChild(
            makePhysicsDebugBox(
                name: "PhysicsDebug_\(placement.type.rawValue)",
                size: debugSize,
                color: physicsDebugColor(for: placement.type),
                center: [0, debugSize.y * 0.5, 0]
            )
        )

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

    private static func physicsDebugSize(for type: PropType) -> SIMD3<Float> {
        switch type {
        case .rock:
            return [0.44, 0.30, 0.40]
        case .treePlaceholder:
            return [0.58, 1.02, 0.58]
        case .crystalPlaceholder:
            return [0.30, 0.62, 0.30]
        }
    }

    private static func physicsDebugColor(for type: PropType) -> NSColor {
        switch type {
        case .rock:
            return .systemOrange
        case .treePlaceholder:
            return .systemGreen
        case .crystalPlaceholder:
            return .systemCyan
        }
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
        let thickness: Float = 0.014
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

    private static func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
