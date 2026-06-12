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
    float exposure;
    float3 skyTint;
    float fogDensity;
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

static float3 isoApplySurfaceBaseColor(
    float3 baseColor,
    float wetness,
    float snow,
    float dust,
    float moss
) {
    float3 color = baseColor;
    color = mix(color, color * 0.62, clamp(wetness, 0.0, 1.0));
    color = mix(color, float3(0.88, 0.92, 0.90), clamp(snow, 0.0, 1.0));
    color = mix(color, min(color * 1.10 + float3(0.05, 0.04, 0.02), float3(1.0)), clamp(dust, 0.0, 1.0) * 0.55);
    color = mix(color, float3(0.14, 0.32, 0.18), clamp(moss, 0.0, 1.0) * 0.72);

    return color;
}

static float isoApplySurfaceRoughness(
    float roughness,
    float wetness,
    float snow,
    float dust,
    float moss
) {
    float value = clamp(roughness, 0.0, 1.0);
    value = mix(value, min(value, 0.18), clamp(wetness, 0.0, 1.0));
    value = mix(value, 0.72, clamp(snow, 0.0, 1.0));
    value = mix(value, 0.94, clamp(dust, 0.0, 1.0));
    value = mix(value, 0.86, clamp(moss, 0.0, 1.0));

    return value;
}

static float3 isoOpaquePBR(IsoPBRInput input) {
    float3 normal = normalize(input.normal);
    float skyFacing = clamp(normal.y * 0.5 + 0.5, 0.0, 1.0);
    float skyIBL = mix(0.08, 0.26, skyFacing) * input.ambientOcclusion;
    float roughnessDiffuse = mix(1.06, 0.90, clamp(input.roughness, 0.0, 1.0));
    float metallicEnergyLoss = mix(1.0, 0.72, clamp(input.metallic, 0.0, 1.0));
    float3 skyTint = max(input.skyTint, float3(0.0));
    float exposure = max(input.exposure, 0.05);
    float3 lit = input.baseColor *
        (input.shade * roughnessDiffuse + skyIBL * skyTint) *
        metallicEnergyLoss;
    float fog = clamp(input.fogDensity, 0.0, 0.35);
    lit = mix(lit, skyTint * 0.52, fog);

    return isoToneMap(lit * 1.35 * exposure);
}

#endif
