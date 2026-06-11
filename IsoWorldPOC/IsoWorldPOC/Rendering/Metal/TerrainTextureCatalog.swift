//
//  TerrainTextureCatalog.swift
//  IsoWorldPOC
//
//  Created by Work on 10/06/2026.
//

import EngineCore
import Metal
import simd

struct TerrainTextureDescriptor {
    let slot: TerrainTextureSlot
    let debugColor: SIMD4<Float>
}

struct TerrainTextureCatalog {
    let albedoTexture: MTLTexture
    let normalTexture: MTLTexture
    let roughnessTexture: MTLTexture
    let metallicAmbientOcclusionTexture: MTLTexture
    let descriptors: [TerrainTextureDescriptor]

    var layerCount: Int {
        Set(descriptors.map(\.slot.textureLayerIndex)).count
    }

    var textureArrayCount: Int {
        Set(descriptors.map(\.slot.map)).count
    }

    static func makePreview(device: MTLDevice?) -> TerrainTextureCatalog? {
        guard let device else {
            return nil
        }

        let albedoSlots = TerrainTextureSlot.allTerrainSlots.sorted {
            $0.textureLayerIndex < $1.textureLayerIndex
        }
        let pbrSlots = TerrainTextureSlot.allTerrainPBRSlots.sorted { lhs, rhs in
            if lhs.map == rhs.map {
                return lhs.textureLayerIndex < rhs.textureLayerIndex
            }

            return lhs.map.rawValue < rhs.map.rawValue
        }

        guard
            let albedoTexture = makeTexture(
                device: device,
                slots: albedoSlots,
                texels: albedoTexels(for:)
            ),
            let normalTexture = makeTexture(
                device: device,
                slots: albedoSlots,
                texels: normalTexels(for:)
            ),
            let roughnessTexture = makeTexture(
                device: device,
                slots: albedoSlots,
                texels: roughnessTexels(for:)
            ),
            let metallicAmbientOcclusionTexture = makeTexture(
                device: device,
                slots: albedoSlots,
                texels: metallicAmbientOcclusionTexels(for:)
            )
        else {
            return nil
        }

        var textureDescriptors: [TerrainTextureDescriptor] = []
        textureDescriptors.reserveCapacity(pbrSlots.count)

        for slot in pbrSlots {
            let material = TerrainMaterialDescriptor.definition(for: slot.materialKind)
            let color = vector(from: material.baseColor)

            textureDescriptors.append(
                TerrainTextureDescriptor(
                    slot: slot,
                    debugColor: SIMD4<Float>(color.x, color.y, color.z, 1)
                )
            )
        }

        return TerrainTextureCatalog(
            albedoTexture: albedoTexture,
            normalTexture: normalTexture,
            roughnessTexture: roughnessTexture,
            metallicAmbientOcclusionTexture: metallicAmbientOcclusionTexture,
            descriptors: textureDescriptors
        )
    }

    private static func makeTexture(
        device: MTLDevice,
        slots: [TerrainTextureSlot],
        texels: (TerrainMaterialDescriptor) -> [UInt8]
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = 2
        descriptor.height = 2
        descriptor.arrayLength = slots.count
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        for slot in slots {
            let material = TerrainMaterialDescriptor.definition(for: slot.materialKind)
            let texels = texels(material)
            let region = MTLRegionMake2D(0, 0, 2, 2)

            texels.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else {
                    return
                }

                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    slice: slot.textureLayerIndex,
                    withBytes: baseAddress,
                    bytesPerRow: 2 * 4,
                    bytesPerImage: 2 * 2 * 4
                )
            }
        }

        return texture
    }

    static func makeSamplerState(device: MTLDevice?) -> MTLSamplerState? {
        guard let device else {
            return nil
        }

        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.mipFilter = .notMipmapped
        descriptor.sAddressMode = .repeat
        descriptor.tAddressMode = .repeat

        return device.makeSamplerState(descriptor: descriptor)
    }

    static func previewColor(for kind: TerrainMaterialKind) -> SIMD4<Float> {
        let material = TerrainMaterialDescriptor.definition(for: kind)
        let color = vector(from: material.baseColor)

        return SIMD4<Float>(color.x, color.y, color.z, 1)
    }

    private static func albedoTexels(for material: TerrainMaterialDescriptor) -> [UInt8] {
        let baseColor = vector(from: material.baseColor)

        return [
            rgbaBytes(baseColor, multiplier: 0.82),
            rgbaBytes(baseColor, multiplier: 1.05),
            rgbaBytes(baseColor, multiplier: 0.96),
            rgbaBytes(baseColor, multiplier: 1.16),
        ].flatMap { $0 }
    }

    private static func normalTexels(for _: TerrainMaterialDescriptor) -> [UInt8] {
        repeatedTexels(r: 128, g: 128, b: 255, a: 255)
    }

    private static func roughnessTexels(for material: TerrainMaterialDescriptor) -> [UInt8] {
        let roughness = byte(material.roughness)

        return repeatedTexels(r: roughness, g: roughness, b: roughness, a: 255)
    }

    private static func metallicAmbientOcclusionTexels(for _: TerrainMaterialDescriptor) -> [UInt8] {
        repeatedTexels(r: 0, g: 255, b: 255, a: 255)
    }

    private static func repeatedTexels(r: UInt8, g: UInt8, b: UInt8, a: UInt8) -> [UInt8] {
        Array(repeating: [r, g, b, a], count: 4).flatMap { $0 }
    }

    private static func rgbaBytes(_ color: SIMD3<Float>, multiplier: Float) -> [UInt8] {
        [
            byte(color.x * multiplier),
            byte(color.y * multiplier),
            byte(color.z * multiplier),
            255,
        ]
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(min(max(value, 0), 1) * 255)
    }

    private static func vector(from color: BiomeColor) -> SIMD3<Float> {
        SIMD3<Float>(color.red, color.green, color.blue)
    }
}
