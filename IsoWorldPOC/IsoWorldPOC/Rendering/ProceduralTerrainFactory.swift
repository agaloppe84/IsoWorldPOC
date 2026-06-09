//
//  ProceduralTerrainFactory.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import AppKit
import EngineCore
import RealityKit

@MainActor
enum ProceduralTerrainFactory {
    static func makeInitialChunkEntity() -> Entity? {
        let horizontalScale: Float = 0.18
        let verticalScale: Float = 0.08
        let coordinate = ChunkCoordinate(x: 0, y: 0, z: 0)
        let heightmap = ChunkGenerator(seed: WorldSeed(12_345)).generateHeightmap(for: coordinate)
        let terrainMesh = TerrainMeshBuilder.build(
            from: heightmap,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        )

        do {
            let meshResource = try RealityKitTerrainAdapter.makeMeshResource(from: terrainMesh)
            let material = SimpleMaterial(
                color: .init(red: 0.20, green: 0.48, blue: 0.25, alpha: 1.0),
                roughness: 0.85,
                isMetallic: false
            )
            let entity = ModelEntity(mesh: meshResource, materials: [material])
            let halfExtent = Float(ChunkHeightmap.resolution - 1) * horizontalScale * 0.5

            entity.name = "ProceduralTerrainChunk_0_0"
            entity.position = [-halfExtent, 0, -halfExtent]

            return entity
        } catch {
            print("Failed to build procedural terrain chunk: \(error)")
            return nil
        }
    }
}
