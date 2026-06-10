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

    private static func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
