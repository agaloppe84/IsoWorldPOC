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

            return ProceduralTerrainChunk(
                coordinate: coordinate,
                biome: biome,
                entity: entity,
                sampler: sampler
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
}
