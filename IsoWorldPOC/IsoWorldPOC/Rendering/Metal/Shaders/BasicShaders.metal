#include <metal_stdlib>
using namespace metal;

struct TerrainVertex {
    float3 position;
    float3 normal;
    float4 color;
    float4 secondaryColor;
    float4 material;
    float4 splatWeights;
    float4 splatMaterialIDs;
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
};

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

vertex TerrainVertexOut terrain_vertex(
    const device TerrainVertex *vertices [[buffer(0)]],
    constant TerrainUniforms &uniforms [[buffer(1)]],
    constant LightingUniforms &lightingUniforms [[buffer(2)]],
    constant DebugUniforms &debugUniforms [[buffer(3)]],
    uint vertexID [[vertex_id]]
) {
    TerrainVertex inputVertex = vertices[vertexID];
    float3 worldNormal = normalize((uniforms.modelMatrix * float4(inputVertex.normal, 0.0)).xyz);
    float3 sunlightTravelDirection = normalize(lightingUniforms.sunDirectionAndIntensity.xyz);
    float3 directionToSun = -sunlightTravelDirection;
    float sunIntensity = lightingUniforms.sunDirectionAndIntensity.w;
    float ambientIntensity = lightingUniforms.ambientAndFlags.x;
    float blendWeight = clamp(inputVertex.material.w, 0.0, 1.0);
    float secondarySplatWeight = clamp(1.0 - inputVertex.splatWeights.x, 0.0, 1.0);
    float roughness = mix(
        clamp(inputVertex.material.x, 0.0, 1.0),
        clamp(inputVertex.material.z, 0.0, 1.0),
        blendWeight
    );
    float3 baseColor = mix(inputVertex.color.rgb, inputVertex.secondaryColor.rgb, blendWeight);
    float diffuse = clamp(dot(worldNormal, directionToSun), 0.0, 1.0);
    float wrappedDiffuse = mix(diffuse, diffuse * 0.82 + 0.18, roughness);
    float shade = clamp(ambientIntensity + wrappedDiffuse * sunIntensity, 0.0, 1.25);
    float terrainMaterialDebugMode = debugUniforms.terrainMaterialModeAndFlags.x;
    int terrainSplatDebugLayerIndex = int(round(debugUniforms.terrainMaterialModeAndFlags.y));
    float materialKind = inputVertex.material.y;
    bool isTerrainMaterial = materialKind >= 1.0 && materialKind <= 6.0;
    float3 outputColor = baseColor * shade;

    if (isTerrainMaterial && terrainMaterialDebugMode > 0.5 && terrainMaterialDebugMode < 1.5) {
        outputColor = inputVertex.color.rgb;
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 1.5 && terrainMaterialDebugMode < 2.5) {
        outputColor = inputVertex.secondaryColor.rgb;
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 2.5 && terrainMaterialDebugMode < 3.5) {
        outputColor = terrainBlendHeatColor(secondarySplatWeight);
    } else if (isTerrainMaterial && terrainMaterialDebugMode >= 3.5) {
        outputColor = terrainWeightHeatColor(splatWeightAt(
            inputVertex.splatWeights,
            terrainSplatDebugLayerIndex
        ));
    }

    TerrainVertexOut out;
    out.position = uniforms.modelViewProjectionMatrix * float4(inputVertex.position, 1.0);
    out.color = float4(outputColor, inputVertex.color.a);
    return out;
}

fragment float4 terrain_fragment(TerrainVertexOut in [[stage_in]]) {
    return in.color;
}
