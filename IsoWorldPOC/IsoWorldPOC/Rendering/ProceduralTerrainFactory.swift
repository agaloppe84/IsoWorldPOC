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
    let entity: Entity
    let sampler: TerrainSampler
}

@MainActor
enum ProceduralTerrainFactory {
    static func makeInitialChunk() -> ProceduralTerrainChunk? {
        let horizontalScale: Float = 0.18
        let verticalScale: Float = 0.08
        let coordinate = ChunkCoordinate(x: 0, y: 0, z: 0)
        let terrainGeometry = coordinate.makeTerrainGeometry(
            seed: WorldSeed(12_345),
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        )

        do {
            let meshResource = try RealityKitTerrainAdapter.makeMeshResource(
                positions: terrainGeometry.positions.map { SIMD3<Float>($0.x, $0.y, $0.z) },
                normals: terrainGeometry.normals.map { SIMD3<Float>($0.x, $0.y, $0.z) },
                textureCoordinates: terrainGeometry.textureCoordinates.map { SIMD2<Float>($0.u, $0.v) },
                indices: terrainGeometry.indices
            )
            let material = SimpleMaterial(
                color: .init(red: 0.20, green: 0.48, blue: 0.25, alpha: 1.0),
                roughness: 0.85,
                isMetallic: false
            )
            let entity = ModelEntity(mesh: meshResource, materials: [material])
            let halfExtent = Float(terrainGeometry.resolution - 1) * horizontalScale * 0.5
            let originX = -halfExtent
            let originZ = -halfExtent
            let sampler = TerrainSampler(
                geometry: terrainGeometry,
                originX: originX,
                originZ: originZ
            )

            entity.name = "ProceduralTerrainChunk_0_0"
            entity.position = [originX, 0, originZ]

            return ProceduralTerrainChunk(entity: entity, sampler: sampler)
        } catch {
            print("Failed to build procedural terrain chunk: \(error)")
            return nil
        }
    }
}
