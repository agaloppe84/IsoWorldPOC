#ifndef ISOWORLD_PBR_SHADER
#define ISOWORLD_PBR_SHADER

#include <metal_stdlib>
using namespace metal;

struct IsoPBRInput {
    float3 baseColor;
    float3 normal;
    float roughness;
    float metallic;
    float ambientOcclusion;
    float shade;
};

static float3 isoToneMap(float3 color) {
    color = max(color, float3(0.0));
    return color / (color + float3(1.0));
}

static float3 isoNormalDebugColor(float3 normal) {
    return normalize(normal) * 0.5 + 0.5;
}

static float3 isoRoughnessDebugColor(float roughness) {
    float value = clamp(roughness, 0.0, 1.0);
    return float3(value, value, value);
}

static float3 isoOpaquePBR(IsoPBRInput input) {
    float3 normal = normalize(input.normal);
    float skyFacing = clamp(normal.y * 0.5 + 0.5, 0.0, 1.0);
    float skyIBL = mix(0.08, 0.26, skyFacing) * input.ambientOcclusion;
    float roughnessDiffuse = mix(1.06, 0.90, clamp(input.roughness, 0.0, 1.0));
    float metallicEnergyLoss = mix(1.0, 0.72, clamp(input.metallic, 0.0, 1.0));
    float3 lit = input.baseColor *
        (input.shade * roughnessDiffuse + skyIBL) *
        metallicEnergyLoss;

    return isoToneMap(lit * 1.35);
}

#endif
