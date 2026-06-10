#include <metal_stdlib>
using namespace metal;

struct TerrainVertex {
    float3 position;
    float3 normal;
    float4 color;
    float4 material;
};

struct TerrainUniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelMatrix;
};

struct LightingUniforms {
    float4 sunDirectionAndIntensity;
    float4 ambientAndFlags;
};

struct TerrainVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex TerrainVertexOut terrain_vertex(
    const device TerrainVertex *vertices [[buffer(0)]],
    constant TerrainUniforms &uniforms [[buffer(1)]],
    constant LightingUniforms &lightingUniforms [[buffer(2)]],
    uint vertexID [[vertex_id]]
) {
    TerrainVertex inputVertex = vertices[vertexID];
    float3 worldNormal = normalize((uniforms.modelMatrix * float4(inputVertex.normal, 0.0)).xyz);
    float3 sunlightTravelDirection = normalize(lightingUniforms.sunDirectionAndIntensity.xyz);
    float3 directionToSun = -sunlightTravelDirection;
    float sunIntensity = lightingUniforms.sunDirectionAndIntensity.w;
    float ambientIntensity = lightingUniforms.ambientAndFlags.x;
    float roughness = clamp(inputVertex.material.x, 0.0, 1.0);
    float diffuse = clamp(dot(worldNormal, directionToSun), 0.0, 1.0);
    float wrappedDiffuse = mix(diffuse, diffuse * 0.82 + 0.18, roughness);
    float shade = clamp(ambientIntensity + wrappedDiffuse * sunIntensity, 0.0, 1.25);

    TerrainVertexOut out;
    out.position = uniforms.modelViewProjectionMatrix * float4(inputVertex.position, 1.0);
    out.color = float4(inputVertex.color.rgb * shade, inputVertex.color.a);
    return out;
}

fragment float4 terrain_fragment(TerrainVertexOut in [[stage_in]]) {
    return in.color;
}
