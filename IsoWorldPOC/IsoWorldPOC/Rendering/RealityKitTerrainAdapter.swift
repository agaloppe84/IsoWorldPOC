//
//  RealityKitTerrainAdapter.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import EngineCore
import RealityKit
import simd

@MainActor
enum RealityKitTerrainAdapter {
    static func makeMeshResource(from terrainMesh: TerrainMesh) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "ProceduralTerrain")
        descriptor.positions = MeshBuffers.Positions(
            terrainMesh.vertices.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        )
        descriptor.normals = MeshBuffers.Normals(
            terrainMesh.normals.map { SIMD3<Float>($0.x, $0.y, $0.z) }
        )
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
            terrainMesh.uvs.map { SIMD2<Float>($0.u, $0.v) }
        )
        descriptor.primitives = .triangles(terrainMesh.indices)

        return try MeshResource.generate(from: [descriptor])
    }
}
