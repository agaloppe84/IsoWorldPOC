#include <metal_stdlib>
using namespace metal;

#include "../Materials/PBRShader.metal"
#include "../Materials/TerrainLayeredShader.metal"

struct TerrainVertex {
    float3 position;
    float3 normal;
    float4 color;
    float4 secondaryColor;
    float4 material;
    float4 splatWeights;
    float4 splatTextureLayerIndices;
    float4 splatUVScales;
    float2 textureCoordinate;
};

struct TerrainUniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelMatrix;
};

struct LightingUniforms {
    float4 sunDirectionAndIntensity;
    float4 ambientAndFlags;
};

struct DebugUniforms {
    float4 terrainMaterialModeAndFlags;
};

struct TerrainVertexOut {
    float4 position [[position]];
    float4 color;
    float4 secondaryColor;
    float4 material;
    float4 splatWeights;
    float4 splatTextureLayerIndices;
    float4 splatUVScales;
    float2 textureCoordinate;
    float3 worldPosition;
    float3 worldNormal;
    float shade;
    float2 debugModeAndSplatLayer;
};

constant float terrainTextureLayerCount = 6.0;

static float3 terrainWeightHeatColor(float weight) {
    float normalizedBlend = clamp(weight, 0.0, 1.0);
    float3 low = float3(0.05, 0.16, 0.90);
    float3 mid = float3(0.10, 0.85, 0.36);
    float3 high = float3(1.00, 0.84, 0.08);

    if (normalizedBlend < 0.5) {
        return mix(low, mid, normalizedBlend * 2.0);
    }

    return mix(mid, high, (normalizedBlend - 0.5) * 2.0);
}

static float3 terrainBlendHeatColor(float blendWeight) {
    return terrainWeightHeatColor(clamp(blendWeight / 0.45, 0.0, 1.0));
}

static float splatWeightAt(float4 weights, int layerIndex) {
    switch (clamp(layerIndex, 0, 3)) {
    case 0:
        return weights.x;
    case 1:
        return weights.y;
    case 2:
        return weights.z;
    default:
        return weights.w;
    }
}

static float4 terrainTextureColor(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float textureLayerIndex,
    float uvScale
) {
    float layer = clamp(round(textureLayerIndex), 0.0, terrainTextureLayerCount - 1.0);
    float2 tiledCoordinate = fract(textureCoordinate * max(uvScale, 0.0001));

    return terrainTextures.sample(terrainSampler, tiledCoordinate, uint(layer));
}

static float4 terrainSplatTextureColor(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float4 weights,
    float4 textureLayerIndices,
    float4 uvScales
) {
    float4 color = float4(0.0);
    float totalWeight = 0.0;

    color += terrainTextureColor(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        textureLayerIndices.x,
        uvScales.x
    ) * weights.x;
    color += terrainTextureColor(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        textureLayerIndices.y,
        uvScales.y
    ) * weights.y;
    color += terrainTextureColor(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        textureLayerIndices.z,
        uvScales.z
    ) * weights.z;
    color += terrainTextureColor(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
        textureLayerIndices.w,
        uvScales.w
    ) * weights.w;
    totalWeight = weights.x + weights.y + weights.z + weights.w;

    if (totalWeight <= 0.0001) {
        return terrainTextureColor(
            terrainTextures,
            terrainSampler,
            textureCoordinate,
            textureLayerIndices.x,
            uvScales.x
        );
    }

    return color / totalWeight;
}

static float terrainSplatTextureChannel(
    texture2d_array<float> terrainTextures,
    sampler terrainSampler,
    float2 textureCoordinate,
    float4 weights,
    float4 textureLayerIndices,
    float4 uvScales,
    int channelIndex
) {
    float4 color = terrainSplatTextureColor(
        terrainTextures,
        terrainSampler,
        textureCoordinate,
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

vertex TerrainVertexOut terrain_vertex(
    const device TerrainVertex *vertices [[buffer(0)]],
    constant TerrainUniforms &uniforms [[buffer(1)]],
    constant LightingUniforms &lightingUniforms [[buffer(2)]],
    constant DebugUniforms &debugUniforms [[buffer(3)]],
    uint vertexID [[vertex_id]]
) {
    TerrainVertex inputVertex = vertices[vertexID];
    float3 worldPosition = (uniforms.modelMatrix * float4(inputVertex.position, 1.0)).xyz;
    float3 worldNormal = normalize((uniforms.modelMatrix * float4(inputVertex.normal, 0.0)).xyz);
    float3 sunlightTravelDirection = normalize(lightingUniforms.sunDirectionAndIntensity.xyz);
    float3 directionToSun = -sunlightTravelDirection;
    float sunIntensity = lightingUniforms.sunDirectionAndIntensity.w;
    float ambientIntensity = lightingUniforms.ambientAndFlags.x;
    float roughness = mix(
        clamp(inputVertex.material.x, 0.0, 1.0),
        clamp(inputVertex.material.z, 0.0, 1.0),
        clamp(inputVertex.material.w, 0.0, 1.0)
    );
    float diffuse = clamp(dot(worldNormal, directionToSun), 0.0, 1.0);
    float wrappedDiffuse = mix(diffuse, diffuse * 0.82 + 0.18, roughness);
    float shade = clamp(ambientIntensity + wrappedDiffuse * sunIntensity, 0.0, 1.25);

    TerrainVertexOut out;
    out.position = uniforms.modelViewProjectionMatrix * float4(inputVertex.position, 1.0);
    out.color = inputVertex.color;
    out.secondaryColor = inputVertex.secondaryColor;
    out.material = inputVertex.material;
    out.splatWeights = inputVertex.splatWeights;
    out.splatTextureLayerIndices = inputVertex.splatTextureLayerIndices;
    out.splatUVScales = inputVertex.splatUVScales;
    out.textureCoordinate = inputVertex.textureCoordinate;
    out.worldPosition = worldPosition;
    out.worldNormal = worldNormal;
    out.shade = shade;
    out.debugModeAndSplatLayer = debugUniforms.terrainMaterialModeAndFlags.xy;
    return out;
}

fragment float4 terrain_fragment(
    TerrainVertexOut in [[stage_in]],
    texture2d_array<float> terrainAlbedoTextures [[texture(0)]],
    texture2d_array<float> terrainNormalTextures [[texture(1)]],
    texture2d_array<float> terrainRoughnessTextures [[texture(2)]],
    texture2d_array<float> terrainMetallicAmbientOcclusionTextures [[texture(3)]],
    sampler terrainSampler [[sampler(0)]]
) {
    float terrainMaterialDebugMode = in.debugModeAndSplatLayer.x;
    int terrainSplatDebugLayerIndex = int(round(in.debugModeAndSplatLayer.y));
    float materialKind = in.material.y;
    bool isTerrainMaterial = materialKind >= 1.0 && materialKind <= 6.0;
    float3 worldNormal = normalize(in.worldNormal);
    float3 outputColor = in.color.rgb;
    float sampledRoughness = clamp(in.material.x, 0.0, 1.0);

    if (isTerrainMaterial) {
        IsoTerrainLayeredSample terrainSample = isoTerrainLayeredSample(
            terrainAlbedoTextures,
            terrainNormalTextures,
            terrainRoughnessTextures,
            terrainMetallicAmbientOcclusionTextures,
            terrainSampler,
            in.textureCoordinate,
            in.worldPosition,
            worldNormal,
            in.splatWeights,
            in.splatTextureLayerIndices,
            in.splatUVScales
        );
        IsoPBRInput pbrInput;
        pbrInput.baseColor = terrainSample.albedo;
        pbrInput.normal = worldNormal;
        pbrInput.roughness = terrainSample.roughness;
        pbrInput.metallic = 0.0;
        pbrInput.ambientOcclusion = terrainSample.ambientOcclusion;
        pbrInput.shade = in.shade;

        sampledRoughness = terrainSample.roughness;
        outputColor = isoOpaquePBR(pbrInput);
    } else {
        outputColor *= in.shade;
    }

    if (isTerrainMaterial && terrainMaterialDebugMode > 0.5 && terrainMaterialDebugMode < 1.5) {
        outputColor = in.color.rgb;
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 1.5 && terrainMaterialDebugMode < 2.5) {
        outputColor = in.secondaryColor.rgb;
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 2.5 && terrainMaterialDebugMode < 3.5) {
        outputColor = terrainBlendHeatColor(clamp(1.0 - in.splatWeights.x, 0.0, 1.0));
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 3.5 && terrainMaterialDebugMode < 4.5) {
        outputColor = terrainWeightHeatColor(splatWeightAt(
            in.splatWeights,
            terrainSplatDebugLayerIndex
        ));
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 4.5 && terrainMaterialDebugMode < 5.5) {
        outputColor = isoRoughnessDebugColor(sampledRoughness);
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 5.5 && terrainMaterialDebugMode < 6.5) {
        outputColor = isoNormalDebugColor(worldNormal);
    }

    return float4(outputColor, in.color.a);
}
