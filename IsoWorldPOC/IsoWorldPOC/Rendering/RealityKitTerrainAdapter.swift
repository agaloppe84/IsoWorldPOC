//
//  RealityKitTerrainAdapter.swift
//  IsoWorldPOC
//
//  Created by Work on 09/06/2026.
//

import RealityKit
import simd

@MainActor
enum RealityKitTerrainAdapter {
    static func makeMeshResource(
        positions: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        textureCoordinates: [SIMD2<Float>],
        indices: [UInt32]
    ) throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "ProceduralTerrain")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        descriptor.primitives = .triangles(indices)

        return try MeshResource.generate(from: [descriptor])
    }
}
