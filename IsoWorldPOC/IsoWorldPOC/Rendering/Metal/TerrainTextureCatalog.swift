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
    let kind: TerrainMaterialKind
    let identifier: String
    let layerIndex: Int
    let debugColor: SIMD4<Float>
}

struct TerrainTextureCatalog {
    static let materialOrder: [TerrainMaterialKind] = [
        .grass,
        .rock,
        .dirt,
        .sand,
        .wetValley,
        .snow,
    ]

    let texture: MTLTexture
    let descriptors: [TerrainTextureDescriptor]

    var layerCount: Int {
        descriptors.count
    }

    static func makePlaceholder(device: MTLDevice?) -> TerrainTextureCatalog? {
        guard let device else {
            return nil
        }

        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2DArray
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = 2
        descriptor.height = 2
        descriptor.arrayLength = materialOrder.count
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        var textureDescriptors: [TerrainTextureDescriptor] = []
        textureDescriptors.reserveCapacity(materialOrder.count)

        for (index, kind) in materialOrder.enumerated() {
            let material = TerrainMaterialDescriptor.definition(for: kind)
            let color = vector(from: material.baseColor)
            let texels = placeholderTexels(baseColor: color)
            let region = MTLRegionMake2D(0, 0, 2, 2)

            texels.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else {
                    return
                }

                texture.replace(
                    region: region,
                    mipmapLevel: 0,
                    slice: index,
                    withBytes: baseAddress,
                    bytesPerRow: 2 * 4,
                    bytesPerImage: 2 * 2 * 4
                )
            }

            textureDescriptors.append(
                TerrainTextureDescriptor(
                    kind: kind,
                    identifier: material.identifier,
                    layerIndex: index,
                    debugColor: SIMD4<Float>(color.x, color.y, color.z, 1)
                )
            )
        }

        return TerrainTextureCatalog(
            texture: texture,
            descriptors: textureDescriptors
        )
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

    static func placeholderColor(for kind: TerrainMaterialKind) -> SIMD4<Float> {
        let material = TerrainMaterialDescriptor.definition(for: kind)
        let color = vector(from: material.baseColor)

        return SIMD4<Float>(color.x, color.y, color.z, 1)
    }

    private static func placeholderTexels(baseColor: SIMD3<Float>) -> [UInt8] {
        [
            rgbaBytes(baseColor, multiplier: 0.82),
            rgbaBytes(baseColor, multiplier: 1.05),
            rgbaBytes(baseColor, multiplier: 0.96),
            rgbaBytes(baseColor, multiplier: 1.16),
        ].flatMap { $0 }
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
