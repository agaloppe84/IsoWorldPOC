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
    let terrainSampleGrid: TerrainSampleGrid
    let terrainVertexMaterials: [TerrainVertexMaterial]
    let traversalData: TraversalChunkData
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

    static func makeChunkData(coordinate: ChunkCoordinate) -> ProceduralChunkData {
        do {
            return try makeChunkData(
                coordinate: coordinate,
                worldSeed: activeSeed,
                cancellationToken: nil
            )
        } catch {
            preconditionFailure("Unexpected cancellation while generating a chunk without a cancellation token.")
        }
    }

    static func makeChunkData(
        coordinate: ChunkCoordinate,
        worldSeed: WorldSeed
    ) -> ProceduralChunkData {
        do {
            return try makeChunkData(
                coordinate: coordinate,
                worldSeed: worldSeed,
                cancellationToken: nil
            )
        } catch {
            preconditionFailure("Unexpected cancellation while generating a chunk without a cancellation token.")
        }
    }

    static func makeChunkData(
        coordinate: ChunkCoordinate,
        cancellationToken: CancellationToken?
    ) throws -> ProceduralChunkData {
        try makeChunkData(
            coordinate: coordinate,
            worldSeed: activeSeed,
            cancellationToken: cancellationToken
        )
    }

    static func makeChunkData(
        coordinate: ChunkCoordinate,
        worldSeed: WorldSeed,
        cancellationToken: CancellationToken?
    ) throws -> ProceduralChunkData {
        let dataGenerationStart = currentTimeMilliseconds()
        let biomeSampler = BiomeSampler(seed: worldSeed)
        let terrainSystem = TerrainSystem(seed: worldSeed)
        let propSystem = PropSystem(seed: worldSeed, maxPropsPerChunk: 28)

        try cancellationToken?.checkCancellation()

        let terrainGeometry = coordinate.makeTerrainGeometry(
            seed: worldSeed,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        )

        try cancellationToken?.checkCancellation()

        let terrainSampleGrid = terrainSystem.sampleGrid(for: coordinate)
        let traversalData = TraversalChunkData(sampleGrid: terrainSampleGrid)

        try cancellationToken?.checkCancellation()

        let biome = biomeSampler.dominantBiome(
            for: coordinate,
            samplesPerChunk: chunkResolution
        )

        try cancellationToken?.checkCancellation()

        let terrainVertexMaterials = try makeTerrainVertexMaterials(
            from: terrainSampleGrid,
            cancellationToken: cancellationToken
        )

        try cancellationToken?.checkCancellation()

        let propChunkData = propSystem.chunkData(
            for: coordinate,
            biome: biome,
            terrainSampleGrid: terrainSampleGrid
        )

        try cancellationToken?.checkCancellation()

        let origin = origin(for: coordinate)

        return ProceduralChunkData(
            coordinate: coordinate,
            biome: biome,
            terrainGeometry: terrainGeometry,
            terrainSampleGrid: terrainSampleGrid,
            terrainVertexMaterials: terrainVertexMaterials,
            traversalData: traversalData,
            meshPositions: terrainGeometry.positions.map { SIMD3<Float>($0.x, $0.y, $0.z) },
            meshNormals: terrainGeometry.normals.map { SIMD3<Float>($0.x, $0.y, $0.z) },
            meshTextureCoordinates: terrainGeometry.textureCoordinates.map { SIMD2<Float>($0.u, $0.v) },
            meshIndices: terrainGeometry.indices,
            propPlacements: propChunkData.placements,
            propVariants: propChunkData.variants,
            originX: origin.x,
            originZ: origin.z,
            dataGenerationTimeMs: Float(currentTimeMilliseconds() - dataGenerationStart)
        )
    }

    static func origin(for coordinate: ChunkCoordinate) -> (x: Float, z: Float) {
        let halfExtent = chunkWorldSize * 0.5

        return (
            x: Float(coordinate.x) * chunkWorldSize - halfExtent,
            z: Float(coordinate.z) * chunkWorldSize - halfExtent
        )
    }

    private static func makeTerrainVertexMaterials(
        from terrainSampleGrid: TerrainSampleGrid,
        cancellationToken: CancellationToken?
    ) throws -> [TerrainVertexMaterial] {
        var materials: [TerrainVertexMaterial] = []
        materials.reserveCapacity(chunkResolution * chunkResolution)

        for sample in terrainSampleGrid.samples {
            try cancellationToken?.checkCancellation()
            materials.append(sample.materialWeights.terrainVertexMaterial())
        }

        return materials
    }

    private static func currentTimeMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }
}
