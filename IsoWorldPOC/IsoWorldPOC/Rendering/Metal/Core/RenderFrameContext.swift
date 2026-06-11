//
//  RenderFrameContext.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import simd

struct MetalFrameContext {
    let snapshot: RenderWorldSnapshot
    let chunkBuffersByCoordinate: [ChunkCoordinate: MetalChunkBuffers]
    let playerBuffers: MetalIndexedMeshBuffers?
    let playerPosition: SIMD3<Float>
    let viewProjectionMatrix: matrix_float4x4

    var visibleChunks: [RenderChunk] {
        snapshot.chunks.filter(\.isVisible)
    }

    var lightingUniforms: MetalLightingUniforms {
        MetalLightingUniforms(state: snapshot.lighting)
    }

    var debugUniforms: MetalRenderDebugUniforms {
        MetalRenderDebugUniforms(options: snapshot.debugOptions)
    }
}

typealias RenderFrameContext = MetalFrameContext

struct MetalLightingUniforms {
    let sunDirectionAndIntensity: SIMD4<Float>
    let ambientAndFlags: SIMD4<Float>

    init(state: LightingState) {
        let rawDirection = vector(from: state.sunDirection)
        let directionLength = simd_length(rawDirection)
        let direction = directionLength > 0.0001
            ? rawDirection / directionLength
            : SIMD3<Float>(0, -1, 0)

        self.sunDirectionAndIntensity = SIMD4<Float>(
            direction.x,
            direction.y,
            direction.z,
            max(state.sunIntensity, 0)
        )
        self.ambientAndFlags = SIMD4<Float>(
            max(state.ambientIntensity, 0),
            state.shadowsEnabled ? 1 : 0,
            0,
            0
        )
    }
}

struct MetalRenderDebugUniforms {
    let terrainMaterialModeAndFlags: SIMD4<Float>

    init(options: RenderDebugOptions) {
        self.terrainMaterialModeAndFlags = SIMD4<Float>(
            Self.modeID(options.terrainMaterialDebugMode),
            Float(options.terrainSplatDebugLayerIndex),
            0,
            0
        )
    }

    private static func modeID(_ mode: TerrainMaterialDebugMode) -> Float {
        switch mode {
        case .normal:
            0
        case .primaryBiome:
            1
        case .secondaryBiome:
            2
        case .blendWeight:
            3
        case .splatLayerWeight:
            4
        case .roughness:
            5
        case .normalVector:
            6
        }
    }
}

struct MetalFrameDrawMetrics {
    var terrainDrawCalls = 0
    var propDrawCalls = 0
    var playerDrawCalls = 0
    var debugDrawCalls = 0
    var terrainChunksDrawn = 0
    var propChunksDrawn = 0
    var propsDrawn = 0
    var debugBoundsDrawn = 0

    static let empty = MetalFrameDrawMetrics()

    var totalDrawCalls: Int {
        terrainDrawCalls + propDrawCalls + playerDrawCalls + debugDrawCalls
    }

    mutating func add(_ other: MetalFrameDrawMetrics) {
        terrainDrawCalls += other.terrainDrawCalls
        propDrawCalls += other.propDrawCalls
        playerDrawCalls += other.playerDrawCalls
        debugDrawCalls += other.debugDrawCalls
        terrainChunksDrawn += other.terrainChunksDrawn
        propChunksDrawn += other.propChunksDrawn
        propsDrawn += other.propsDrawn
        debugBoundsDrawn += other.debugBoundsDrawn
    }
}

func makeMetalUniforms(
    origin: WorldPosition,
    viewProjectionMatrix: matrix_float4x4
) -> MetalTerrainUniforms {
    makeMetalUniforms(
        modelMatrix: matrixTranslation(vector(from: origin)),
        viewProjectionMatrix: viewProjectionMatrix
    )
}

func makeMetalUniforms(
    modelMatrix: matrix_float4x4,
    viewProjectionMatrix: matrix_float4x4
) -> MetalTerrainUniforms {
    MetalTerrainUniforms(
        modelViewProjectionMatrix: viewProjectionMatrix * modelMatrix,
        modelMatrix: modelMatrix
    )
}
