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
    let chunkDataGenerationTimeMs: Float
    let terrainMeshBuildTimeMs: Float
}

struct ProceduralChunkData: Sendable {
    let coordinate: ChunkCoordinate
    let biome: Biome
    let terrainGeometry: TerrainGeometryBuffers
    let meshPositions: [SIMD3<Float>]
    let meshNormals: [SIMD3<Float>]
    let meshTextureCoordinates: [SIMD2<Float>]
    let meshIndices: [UInt32]
    let propPlacements: [PropPlacement]
    let propVariants: [PropVariant]
    let originX: Float
    let originZ: Float
    let dataGenerationTimeMs: Float
}

struct ProceduralTerrainChunk {
    let coordinate: ChunkCoordinate
    let biome: Biome
    let entity: Entity
    let sampler: TerrainSampler
    let propCount: Int
    let buildMetrics: ProceduralChunkBuildMetrics
}

enum ProceduralTerrainFactory {
    static let horizontalScale: Float = 0.18
    static let verticalScale: Float = 0.08
    static let activeSeed = WorldSeed(12_345)
    static let chunkResolution = 64
    static let chunkWorldSize = Float(chunkResolution - 1) * horizontalScale
    static let triangleCountPerChunk = (chunkResolution - 1) * (chunkResolution - 1) * 2
    static let biomeSampler = BiomeSampler(seed: activeSeed)
    static let propGenerator = PropPlacementGenerator(seed: activeSeed, maxPropsPerChunk: 18)
    static let assetGenerator = ProceduralAssetGenerator(seed: activeSeed)

    static func makeChunkData(coordinate: ChunkCoordinate) -> ProceduralChunkData {
        let dataGenerationStart = currentTimeMilliseconds()
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
        let propVariants = propPlacements.map { placement in
            assetGenerator.variant(
                for: placement,
                biome: biome,
                chunk: coordinate
            )
        }
        let halfExtent = chunkWorldSize * 0.5
        let originX = Float(coordinate.x) * chunkWorldSize - halfExtent
        let originZ = Float(coordinate.z) * chunkWorldSize - halfExtent

        return ProceduralChunkData(
            coordinate: coordinate,
            biome: biome,
            terrainGeometry: terrainGeometry,
            meshPositions: terrainGeometry.positions.map { SIMD3<Float>($0.x, $0.y, $0.z) },
            meshNormals: terrainGeometry.normals.map { SIMD3<Float>($0.x, $0.y, $0.z) },
            meshTextureCoordinates: terrainGeometry.textureCoordinates.map { SIMD2<Float>($0.u, $0.v) },
            meshIndices: terrainGeometry.indices,
            propPlacements: propPlacements,
            propVariants: propVariants,
            originX: originX,
            originZ: originZ,
            dataGenerationTimeMs: Float(currentTimeMilliseconds() - dataGenerationStart)
        )
    }

    @MainActor
    static func makeInitialChunk() -> ProceduralTerrainChunk? {
        makeChunk(coordinate: .origin)
    }

    @MainActor
    static func makeChunk(coordinate: ChunkCoordinate) -> ProceduralTerrainChunk? {
        makeChunk(from: makeChunkData(coordinate: coordinate))
    }

    @MainActor
    static func makeChunk(from data: ProceduralChunkData) -> ProceduralTerrainChunk? {
        do {
            let meshBuildStart = currentTimeMilliseconds()
            let meshResource = try RealityKitTerrainAdapter.makeMeshResource(
                positions: data.meshPositions,
                normals: data.meshNormals,
                textureCoordinates: data.meshTextureCoordinates,
                indices: data.meshIndices
            )
            let terrainMeshBuildTimeMs = Float(currentTimeMilliseconds() - meshBuildStart)
            let material = material(for: data.biome.terrainMaterial)
            let entity = ModelEntity(mesh: meshResource, materials: [material])
            let sampler = TerrainSampler(
                geometry: data.terrainGeometry,
                originX: data.originX,
                originZ: data.originZ
            )

            entity.name = "ProceduralTerrainChunk_\(data.coordinate.x)_\(data.coordinate.z)"
            entity.position = [data.originX, 0, data.originZ]

            for variant in data.propVariants {
                entity.addChild(
                    makePropEntity(
                        for: variant,
                        sampler: sampler,
                        originX: data.originX,
                        originZ: data.originZ
                    )
                )
            }

            let buildMetrics = ProceduralChunkBuildMetrics(
                chunkDataGenerationTimeMs: data.dataGenerationTimeMs,
                terrainMeshBuildTimeMs: terrainMeshBuildTimeMs
            )

            return ProceduralTerrainChunk(
                coordinate: data.coordinate,
                biome: data.biome,
                entity: entity,
                sampler: sampler,
                propCount: data.propVariants.count,
                buildMetrics: buildMetrics
            )
        } catch {
            print("Failed to build procedural terrain chunk \(data.coordinate): \(error)")
            return nil
        }
    }

    @MainActor
    private static func material(for descriptor: TerrainMaterialDescriptor) -> SimpleMaterial {
        SimpleMaterial(
            color: color(for: descriptor.baseColor),
            roughness: MaterialScalarParameter(floatLiteral: descriptor.roughness),
            isMetallic: false
        )
    }

    @MainActor
    private static func color(for color: BiomeColor) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: 1.0
        )
    }

    @MainActor
    private static func makePropEntity(
        for variant: PropVariant,
        sampler: TerrainSampler,
        originX: Float,
        originZ: Float
    ) -> Entity {
        let placement = variant.placement
        let prop = Entity()
        let localX = placement.localX * horizontalScale
        let localZ = placement.localZ * horizontalScale
        let worldX = originX + localX
        let worldZ = originZ + localZ
        let terrainHeight = sampler.heightAt(x: worldX, z: worldZ)

        prop.name = "Prop_\(placement.type.rawValue)"
        prop.position = [localX, terrainHeight + 0.02, localZ]
        prop.orientation = simd_quatf(angle: placement.rotationRadians, axis: [0, 1, 0])

        prop.addChild(RealityKitPropAdapter.makeEntity(for: variant))

        let debugSize = simd(variant.collisionSize)
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

    @MainActor
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

    @MainActor
    private static func makePhysicsDebugBox(
        name: String,
        size: SIMD3<Float>,
        color: NSColor,
        center: SIMD3<Float>
    ) -> Entity {
        let box = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: 0.02),
            materials: [
                SimpleMaterial(
                    color: color.withAlphaComponent(0.18),
                    roughness: 0.35,
                    isMetallic: false
                )
            ]
        )
        box.name = name
        box.position = center

        return box
    }

    private static func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }

    private static func simd(_ vector: PropVector3) -> SIMD3<Float> {
        [vector.x, vector.y, vector.z]
    }
}
