#include <metal_stdlib>
#include <UntoldEngineShaderSupport/UntoldModelSurface.h>

using namespace metal;

kernel void waterFixtureTextureKernel(
    texture2d<float, access::write> waterColor [[texture(0)]],
    texture2d<float, access::write> waterNormal [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= waterColor.get_width() || gid.y >= waterColor.get_height()) {
        return;
    }

    float2 size = float2(waterColor.get_width(), waterColor.get_height());
    float2 uv = (float2(gid) + 0.5) / size;
    float wave = sin(uv.x * 42.0) * cos(uv.y * 31.0);
    float normalizedWave = wave * 0.5 + 0.5;
    float3 color = mix(float3(0.01, 0.12, 0.22), float3(0.10, 0.55, 0.68), normalizedWave);
    float3 normal = normalize(float3(-wave * 0.18, 1.0, wave * 0.12));

    waterColor.write(float4(color, 1.0), gid);
    waterNormal.write(float4(normal * 0.5 + 0.5, normalizedWave), gid);
}

struct WaterFixtureSurfaceUniforms {
    float4 tint;
    float roughness;
    float waveStrength;
    float padding0;
    float padding1;
};

fragment float4 waterFixtureSurfaceFragment(
    UntoldModelSurfaceVertexOut in [[stage_in]],
    constant UntoldModelSurfaceExtensionArguments &arguments
        [[buffer(UntoldModelSurfaceExtensionArgumentBufferIndex)]]
) {
    constexpr sampler surfaceSampler(
        min_filter::linear,
        mag_filter::linear,
        mip_filter::none,
        address::repeat
    );
    constant WaterFixtureSurfaceUniforms &uniforms =
        *reinterpret_cast<constant WaterFixtureSurfaceUniforms *>(arguments.buffer0);

    float2 uv = float2(in.uvCoords.x, 1.0 - in.uvCoords.y);
    float4 color = arguments.texture0.sample(surfaceSampler, uv);
    float4 normalWave = arguments.texture1.sample(surfaceSampler, uv);
    float highlight = normalWave.a * uniforms.waveStrength * (1.0 - uniforms.roughness);
    float3 tinted = mix(color.rgb, uniforms.tint.rgb, 0.45) + highlight;
    float alpha = clamp(uniforms.tint.a, 0.0, 1.0);
    return float4(tinted * alpha, alpha);
}

struct WaterFixtureProceduralVertexOut {
    float4 position [[position]];
    float3 color;
};

vertex WaterFixtureProceduralVertexOut waterFixtureProceduralVertex(
    uint vertexID [[vertex_id]],
    constant float4x4 &viewProjection [[buffer(0)]]
) {
    constexpr float3 positions[] = {
        float3(-0.8, 0.15, 0.0),
        float3( 0.8, 0.15, 0.0),
        float3( 0.0, 1.35, 0.0),
    };
    constexpr float3 colors[] = {
        float3(0.02, 0.20, 0.38),
        float3(0.04, 0.55, 0.72),
        float3(0.20, 0.82, 0.88),
    };

    WaterFixtureProceduralVertexOut out;
    out.position = viewProjection * float4(positions[vertexID], 1.0);
    out.color = colors[vertexID];
    return out;
}

fragment float4 waterFixtureProceduralFragment(
    WaterFixtureProceduralVertexOut in [[stage_in]]
) {
    float alpha = 0.82;
    return float4(in.color * alpha, alpha);
}
