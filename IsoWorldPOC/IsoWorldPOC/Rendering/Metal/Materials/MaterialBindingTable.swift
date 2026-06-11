//
//  MaterialBindingTable.swift
//  IsoWorldPOC
//
//  Created by Codex on 11/06/2026.
//

import EngineCore
import Metal

struct TerrainLayerBinding: Equatable {
    let materialKind: TerrainMaterialKind
    let textureLayerIndex: Int
    let uvScale: Float
    let albedoSlot: TerrainTextureSlot
    let normalSlot: TerrainTextureSlot
    let roughnessSlot: TerrainTextureSlot
    let metallicAmbientOcclusionSlot: TerrainTextureSlot
}

struct MaterialBindingTable {
    static let terrainAlbedoTextureIndex = 0
    static let terrainNormalTextureIndex = 1
    static let terrainRoughnessTextureIndex = 2
    static let terrainMetallicAmbientOcclusionTextureIndex = 3
    static let terrainSamplerIndex = 0

    let terrainLayerBindings: [TerrainLayerBinding]

    var terrainLayerCount: Int {
        terrainLayerBindings.count
    }

    var terrainTextureArrayCount: Int {
        terrainLayerBindings.isEmpty ? 0 : TerrainTextureMap.allCases.count
    }

    init(terrainTextureCatalog: TerrainTextureCatalog?) {
        self.init(descriptors: terrainTextureCatalog?.descriptors ?? [])
    }

    init(descriptors: [TerrainTextureDescriptor]) {
        var descriptorsByKindAndMap: [TerrainMaterialKind: [TerrainTextureMap: TerrainTextureSlot]] = [:]

        for descriptor in descriptors {
            descriptorsByKindAndMap[descriptor.slot.materialKind, default: [:]][descriptor.slot.map] = descriptor.slot
        }

        terrainLayerBindings = TerrainMaterialKind.allCases.compactMap { kind in
            guard
                let slotsByMap = descriptorsByKindAndMap[kind],
                let albedo = slotsByMap[.albedo],
                let normal = slotsByMap[.normal],
                let roughness = slotsByMap[.roughness],
                let metallicAmbientOcclusion = slotsByMap[.metallicAmbientOcclusion]
            else {
                return nil
            }

            return TerrainLayerBinding(
                materialKind: kind,
                textureLayerIndex: albedo.textureLayerIndex,
                uvScale: albedo.uvScale,
                albedoSlot: albedo,
                normalSlot: normal,
                roughnessSlot: roughness,
                metallicAmbientOcclusionSlot: metallicAmbientOcclusion
            )
        }
    }

    func binding(for kind: TerrainMaterialKind) -> TerrainLayerBinding? {
        terrainLayerBindings.first { $0.materialKind == kind }
    }

    func bindTerrainTextures(
        catalog: TerrainTextureCatalog,
        samplerState: MTLSamplerState,
        renderEncoder: MTLRenderCommandEncoder
    ) {
        renderEncoder.setFragmentTexture(
            catalog.albedoTexture,
            index: Self.terrainAlbedoTextureIndex
        )
        renderEncoder.setFragmentTexture(
            catalog.normalTexture,
            index: Self.terrainNormalTextureIndex
        )
        renderEncoder.setFragmentTexture(
            catalog.roughnessTexture,
            index: Self.terrainRoughnessTextureIndex
        )
        renderEncoder.setFragmentTexture(
            catalog.metallicAmbientOcclusionTexture,
            index: Self.terrainMetallicAmbientOcclusionTextureIndex
        )
        renderEncoder.setFragmentSamplerState(
            samplerState,
            index: Self.terrainSamplerIndex
        )
    }
}
