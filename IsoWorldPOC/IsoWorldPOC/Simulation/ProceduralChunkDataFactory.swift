//
//  ProceduralChunkDataFactory.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Foundation
import simd

struct ProceduralChunkData: Sendable {
    let coordinate: ChunkCoordinate
    let biome: Biome
    let terrainGeometry: TerrainGeometryBuffers
    let terrainVertexMaterials: [TerrainVertexMaterial]
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

enum ProceduralChunkDataFactory {
    static let horizontalScale: Float = 0.18
    static let verticalScale: Float = 0.08
    static let activeSeed = WorldSeed(12_345)
    static let chunkResolution = 64
    static let chunkWorldSize = Float(chunkResolution - 1) * horizontalScale
    static let triangleCountPerChunk = (chunkResolution - 1) * (chunkResolution - 1) * 2

    private static let biomeSampler = BiomeSampler(seed: activeSeed)
    private static let propGenerator = PropPlacementGenerator(seed: activeSeed, maxPropsPerChunk: 18)
    private static let assetGenerator = ProceduralAssetGenerator(seed: activeSeed)

    static func makeChunkData(coordinate: ChunkCoordinate) -> ProceduralChunkData {
        do {
            return try makeChunkData(coordinate: coordinate, cancellationToken: nil)
        } catch {
            preconditionFailure("Unexpected cancellation while generating a chunk without a cancellation token.")
        }
    }

    static func makeChunkData(
        coordinate: ChunkCoordinate,
        cancellationToken: CancellationToken?
    ) throws -> ProceduralChunkData {
        let dataGenerationStart = currentTimeMilliseconds()

        try cancellationToken?.checkCancellation()

        let terrainGeometry = coordinate.makeTerrainGeometry(
            seed: activeSeed,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        )

        try cancellationToken?.checkCancellation()

        let biome = biomeSampler.dominantBiome(
            for: coordinate,
            samplesPerChunk: chunkResolution
        )

        try cancellationToken?.checkCancellation()

        let terrainVertexMaterials = try makeTerrainVertexMaterials(
            for: coordinate,
            cancellationToken: cancellationToken
        )

        try cancellationToken?.checkCancellation()

        let propPlacements = propGenerator.placements(
            for: coordinate,
            biome: biome,
            samplesPerChunk: chunkResolution
        )

        var propVariants: [PropVariant] = []
        propVariants.reserveCapacity(propPlacements.count)

        for placement in propPlacements {
            try cancellationToken?.checkCancellation()
            propVariants.append(assetGenerator.variant(
                for: placement,
                biome: biome,
                chunk: coordinate
            ))
        }

        try cancellationToken?.checkCancellation()

        let halfExtent = chunkWorldSize * 0.5
        let originX = Float(coordinate.x) * chunkWorldSize - halfExtent
        let originZ = Float(coordinate.z) * chunkWorldSize - halfExtent

        return ProceduralChunkData(
            coordinate: coordinate,
            biome: biome,
            terrainGeometry: terrainGeometry,
            terrainVertexMaterials: terrainVertexMaterials,
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

    private static func makeTerrainVertexMaterials(
        for coordinate: ChunkCoordinate,
        cancellationToken: CancellationToken?
    ) throws -> [TerrainVertexMaterial] {
        var materials: [TerrainVertexMaterial] = []
        materials.reserveCapacity(chunkResolution * chunkResolution)

        for localZ in 0..<chunkResolution {
            try cancellationToken?.checkCancellation()

            for localX in 0..<chunkResolution {
                materials.append(
                    biomeSampler.terrainVertexMaterial(
                        for: coordinate,
                        localX: localX,
                        localZ: localZ,
                        samplesPerChunk: chunkResolution
                    )
                )
            }
        }

        return materials
    }

    private static func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
