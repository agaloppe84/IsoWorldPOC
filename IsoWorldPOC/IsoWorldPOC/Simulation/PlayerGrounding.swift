//
//  PlayerGrounding.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import simd

struct TerrainGroundSample {
    let sample: TerrainSampler.Sample
    let terrainSample: TerrainSample?
    let surfaceClass: TraversalSurfaceClass?
    let chunk: ChunkCoordinate

    init(
        sample: TerrainSampler.Sample,
        terrainSample: TerrainSample? = nil,
        surfaceClass: TraversalSurfaceClass?,
        chunk: ChunkCoordinate
    ) {
        self.sample = sample
        self.terrainSample = terrainSample
        self.surfaceClass = surfaceClass
        self.chunk = chunk
    }

    func isWalkable(maxSlope: Float) -> Bool {
        if let surfaceClass {
            return surfaceClass.isWalkableForPlayer
        }

        return sample.isWalkable(maxSlope: maxSlope)
    }

    func contactPatch(worldX: Float, worldZ: Float) -> ContactPatch? {
        guard let terrainSample else {
            return nil
        }

        return SurfaceContactResolver().patch(
            for: terrainSample,
            worldX: worldX,
            worldZ: worldZ,
            coordinate: chunk,
            surfaceClass: surfaceClass
        )
    }
}

struct PlayerGroundingResult {
    let position: SIMD3<Float>
    let groundSample: TerrainGroundSample?
    let playerGrounded: Bool
    let movementBlockedBySlope: Bool

    var terrainHeight: Float? {
        groundSample?.sample.height
    }

    var slopeUnderPlayer: Float? {
        groundSample?.sample.slope
    }

    var currentGroundChunk: ChunkCoordinate? {
        groundSample?.chunk
    }
}

struct PlayerGrounding {
    let surfaceOffset: Float
    let maxWalkableSlope: Float

    init(surfaceOffset: Float = 0.02, maxWalkableSlope: Float = 0.65) {
        self.surfaceOffset = surfaceOffset
        self.maxWalkableSlope = maxWalkableSlope
    }

    func resolve(
        previousPosition: SIMD3<Float>,
        proposedPosition: SIMD3<Float>,
        proposedGround: TerrainGroundSample?,
        previousGround: TerrainGroundSample?
    ) -> PlayerGroundingResult {
        if let proposedGround, proposedGround.isWalkable(maxSlope: maxWalkableSlope) {
            return groundedResult(
                horizontalPosition: proposedPosition,
                groundSample: proposedGround,
                movementBlockedBySlope: false
            )
        }

        if let previousGround {
            return groundedResult(
                horizontalPosition: previousPosition,
                groundSample: previousGround,
                movementBlockedBySlope: proposedGround != nil
            )
        }

        if let proposedGround {
            return groundedResult(
                horizontalPosition: proposedPosition,
                groundSample: proposedGround,
                movementBlockedBySlope: true
            )
        }

        return PlayerGroundingResult(
            position: previousPosition,
            groundSample: nil,
            playerGrounded: false,
            movementBlockedBySlope: false
        )
    }

    private func groundedResult(
        horizontalPosition: SIMD3<Float>,
        groundSample: TerrainGroundSample,
        movementBlockedBySlope: Bool
    ) -> PlayerGroundingResult {
        var groundedPosition = horizontalPosition
        groundedPosition.y = groundSample.sample.height + surfaceOffset

        return PlayerGroundingResult(
            position: groundedPosition,
            groundSample: groundSample,
            playerGrounded: true,
            movementBlockedBySlope: movementBlockedBySlope
        )
    }
}
