#include <metal_stdlib>
using namespace metal;

struct TerrainVertex {
    float3 position;
    float3 normal;
    float4 color;
};

struct TerrainUniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelMatrix;
};

struct TerrainVertexOut {
    float4 position [[position]];
    float4 color;
};

vertex TerrainVertexOut terrain_vertex(
    const device TerrainVertex *vertices [[buffer(0)]],
    constant TerrainUniforms &uniforms [[buffer(1)]],
    uint vertexID [[vertex_id]]
) {
    TerrainVertex inputVertex = vertices[vertexID];
    float3 worldNormal = normalize((uniforms.modelMatrix * float4(inputVertex.normal, 0.0)).xyz);
    float3 lightDirection = normalize(float3(-0.35, 0.85, -0.25));
    float lighting = clamp(dot(worldNormal, lightDirection), 0.0, 1.0);
    float shade = mix(0.38, 1.0, lighting);

    TerrainVertexOut out;
    out.position = uniforms.modelViewProjectionMatrix * float4(inputVertex.position, 1.0);
    out.color = float4(inputVertex.color.rgb * shade, inputVertex.color.a);
    return out;
}

fragment float4 terrain_fragment(TerrainVertexOut in [[stage_in]]) {
    return in.color;
}
