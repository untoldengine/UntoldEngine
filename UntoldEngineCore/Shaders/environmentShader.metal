//
//  environmentShader.metal
//  UntoldEngineVisionOS
//
//  Created by Harold Serrano on 11/14/23.
//

#include <metal_stdlib>
#import "ShaderTypes.h"
#include "ShaderStructs.h"

using namespace metal;


[[vertex]] VertexEnvOut vertexEnvironmentShader(VertexEnvIn in [[stage_in]],
                                                constant EnvironmentConstants &environment [[buffer(4)]]){

    VertexEnvOut out;
    out.position = environment.projectionMatrix *environment.viewMatrix *float4(in.position,1.0);
    out.normals = -in.normals;
    out.texCoords = in.texCoords;
    return out;
    
}

static float2 EquirectUVFromCubeDirection(float3 v) {
    const float2 scales { 0.1591549f, 0.3183099f };
    const float2 biases { 0.5f, 0.5f };
    // Assumes +Z is forward. For -X forward, use atan2(v.z, v.x) below instead.
    float2 uv = float2(atan2(-v.x, v.z), asin(-v.y)) * scales + biases;
    return uv;
}

[[fragment]] float4 fragmentEnvironmentShader(VertexEnvOut in [[stage_in]],
                                              texture2d<float> environmentTexture [[texture(0)]]){
    
    constexpr sampler environmentSampler(coord::normalized,
                                         filter::linear,
                                         mip_filter::none,
                                         address::repeat);

    float3 N = normalize(in.normals);
    float2 texCoords = EquirectUVFromCubeDirection(N);
    float4 color = environmentTexture.sample(environmentSampler, texCoords);
    
    return color;
    
}

