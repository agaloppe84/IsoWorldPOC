#ifndef ISOWORLD_TERRAIN_LAYERED_SHADER
#define ISOWORLD_TERRAIN_LAYERED_SHADER

#include <metal_stdlib>
using namespace metal;

constant float isoTerrainTextureLayerCount = 6.0;

struct IsoTerrainLayeredSample {
    float3 albedo;
    float roughness;
    float ambientOcclusion;
    float normalBlue;
    float triplanarBlend;
};

static float3 isoTerrainTriplanarWeights(float3 normal) {
    float3 weights = pow(abs(normalize(normal)), float3(4.0));
    float total = max(weights.x + weights.y + weights.z, 0.0001);

    return weights / total;
}

static float2 isoTerrainPlanarUV(float3 worldPosition, int axis, float uvScale) {
    float scale = max(uvScale / 63.0, 0.0001);

    switch (axis) {
    case 0:
        return worldPosition.zy * scale;
    case 1:
        return worldPosition.xz * scale;
    default:
        return worldPosition.xy * scale;
    }
}

static float4 isoTerrainTextureLayer(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 uv,
    float textureLayerIndex
) {
    float layer = clamp(round(textureLayerIndex), 0.0, isoTerrainTextureLayerCount - 1.0);

    return terrainTextures.sample(terrainSampler, fract(uv), uint(layer));
}

static float4 isoTerrainTextureLayerUV(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float textureLayerIndex,
    float uvScale
) {
    return isoTerrainTextureLayer(
        terrainTextures,
        terrainSampler,
        textureCoordinate * max(uvScale, 0.0001),
        textureLayerIndex
    );
}

static float4 isoTerrainTextureLayerTriplanar(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float3 worldPosition,
    float3 worldNormal,
    float textureLayerIndex,
    float uvScale
) {
    float3 weights = isoTerrainTriplanarWeights(worldNormal);
    float4 xProjection = isoTerrainTextureLayer(
        terrainTextures,
        terrainSampler,
        isoTerrainPlanarUV(worldPosition, 0, uvScale),
        textureLayerIndex
    );
    float4 yProjection = isoTerrainTextureLayer(
        terrainTextures,
        terrainSampler,
        isoTerrainPlanarUV(worldPosition, 1, uvScale),
        textureLayerIndex
    );
    float4 zProjection = isoTerrainTextureLayer(
        terrainTextures,
        terrainSampler,
        isoTerrainPlanarUV(worldPosition, 2, uvScale),
        textureLayerIndex
    );

    return xProjection * weights.x + yProjection * weights.y + zProjection * weights.z;
}

static float4 isoTerrainTextureLayered(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float3 worldPosition,
    float3 worldNormal,
    float textureLayerIndex,
    float uvScale
) {
    float steepness = 1.0 - abs(normalize(worldNormal).y);
    float triplanarBlend = smoothstep(0.55, 0.82, steepness);
    float4 uvSample = isoTerrainTextureLayerUV(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        textureLayerIndex,
        uvScale
    );
    float4 triplanarSample = isoTerrainTextureLayerTriplanar(
        terrainTextures,
        terrainSampler,
        worldPosition,
        worldNormal,
        textureLayerIndex,
        uvScale
    );

    return mix(uvSample, triplanarSample, triplanarBlend);
}

static float4 isoTerrainSplatTextureColor(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float3 worldPosition,
    float3 worldNormal,
    float4 weights,
    float4 textureLayerIndices,
    float4 uvScales
) {
    float4 color = float4(0.0);
    float totalWeight = weights.x + weights.y + weights.z + weights.w;

    color += isoTerrainTextureLayered(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        textureLayerIndices.x,
        uvScales.x
    ) * weights.x;
    color += isoTerrainTextureLayered(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        textureLayerIndices.y,
        uvScales.y
    ) * weights.y;
    color += isoTerrainTextureLayered(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        textureLayerIndices.z,
        uvScales.z
    ) * weights.z;
    color += isoTerrainTextureLayered(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        textureLayerIndices.w,
        uvScales.w
    ) * weights.w;

    if (totalWeight <= 0.0001) {
        return isoTerrainTextureLayered(
            terrainTextures,
            terrainSampler,
            textureCoordinate,
            worldPosition,
            worldNormal,
            textureLayerIndices.x,
            uvScales.x
        );
    }

    return color / totalWeight;
}

static float isoTerrainSplatTextureChannel(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float3 worldPosition,
    float3 worldNormal,
    float4 weights,
    float4 textureLayerIndices,
    float4 uvScales,
    int channelIndex
) {
    float4 color = isoTerrainSplatTextureColor(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        weights,
        textureLayerIndices,
        uvScales
    );

    switch (clamp(channelIndex, 0, 3)) {
    case 0:
        return color.r;
    case 1:
        return color.g;
    case 2:
        return color.b;
    default:
        return color.a;
    }
}

static IsoTerrainLayeredSample isoTerrainLayeredSample(
    texture2d_array<float> albedoTextures,
    texture2d_array<float> normalTextures,
    texture2d_array<float> roughnessTextures,
    texture2d_array<float> metallicAmbientOcclusionTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float3 worldPosition,
    float3 worldNormal,
    float4 weights,
    float4 textureLayerIndices,
    float4 uvScales
) {
    float steepness = 1.0 - abs(normalize(worldNormal).y);
    IsoTerrainLayeredSample sample;

    sample.albedo = isoTerrainSplatTextureColor(
        albedoTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        weights,
        textureLayerIndices,
        uvScales
    ).rgb;
    sample.roughness = isoTerrainSplatTextureChannel(
        roughnessTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        weights,
        textureLayerIndices,
        uvScales,
        0
    );
    sample.ambientOcclusion = isoTerrainSplatTextureChannel(
        metallicAmbientOcclusionTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        weights,
        textureLayerIndices,
        uvScales,
        1
    );
    sample.normalBlue = isoTerrainSplatTextureChannel(
        normalTextures,
        terrainSampler,
        textureCoordinate,
        worldPosition,
        worldNormal,
        weights,
        textureLayerIndices,
        uvScales,
        2
    );
    sample.triplanarBlend = smoothstep(0.55, 0.82, steepness);

    return sample;
}

#endif
