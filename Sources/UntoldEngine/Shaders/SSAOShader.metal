//
//  SSAOShader.metal
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
using namespace metal;

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexSSAOShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentSSAOShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   constant float3 *ssaoKernel [[buffer(ssaoPassKernelIndex)]],
                                   constant float4x4 &projection [[buffer(ssaoPassPerspectiveSpaceIndex)]],
                                   constant float4x4 &viewSpace [[buffer(ssaoPassViewSpaceIndex)]],
                                   texture2d<float> normalMap [[texture(ssaoNormalMapTextureIndex)]],
                                   texture2d<float> positionMap [[texture(ssaoPositionMapTextureIndex)]],
                                   texture2d<float> ssaoNoiseMap [[texture(ssaoNoiseMapTextureIndex)]],
                                   constant int &kernelSize [[buffer(ssaoPassKernelSizeIndex)]],
                                   constant float2 &viewPort [[buffer(ssaoPassViewPortIndex)]],
                                   constant float &radius [[buffer(ssaoPassRadiusIndex)]],
                                   constant float &bias [[buffer(ssaoPassBiasIndex)]],
                                   //constant float &intensity[[buffer(ssaoPassIntensityIndex)]],
                                   constant bool &enabled[[buffer(ssaoPassEnabledIndex)]]
                                   )
{
    if (!enabled){
        return float4(1.0,1.0,1.0, 1.0);
    }
    
    // Base Color and Normal Maps: Linear filtering, mipmaps, repeat wrapping
    constexpr sampler s(min_filter::linear, mag_filter::linear, mip_filter::none,
                        s_address::clamp_to_edge, t_address::clamp_to_edge);
    
    constexpr sampler normalSampler(min_filter::linear, mag_filter::linear, mip_filter::none,
                                    s_address::clamp_to_edge, t_address::clamp_to_edge);

    float2 noiseScale = float2(viewPort.x/4.0, viewPort.y/4.0);
    
    // Sample position and normal once
    float3 worldPos = positionMap.sample(s, vertexOut.uvCoords).xyz;
    float3 normalWS = normalMap.sample(normalSampler, vertexOut.uvCoords).xyz;
    
    // Precompute view space transformation (hoist out of loop)
    // Extract the 3x3 portion of the view matrix
    float3x3 view3x3 = float3x3(viewSpace.columns[0].xyz,
                                viewSpace.columns[1].xyz,
                                viewSpace.columns[2].xyz);
    
    float3 fragPos = (viewSpace * float4(worldPos, 1.0)).xyz;
    float3 normal = normalize(view3x3 * normalWS);
    
    // Build TBN matrix once
    float3 randomVec = ssaoNoiseMap.sample(s, vertexOut.uvCoords * noiseScale).xyz;
    float3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    float3 bitangent = cross(normal, tangent);
    float3x3 TBN = float3x3(tangent, bitangent, normal);
    
    // Precompute constants for range check
    float invKernelSize = 1.0 / float(kernelSize);
    float fragPosZ = fragPos.z;
    
    float occlusion = 0.0;
    
    // Optimized sample loop - all setup done outside
    for(int i=0; i<kernelSize; ++i){
        // Transform sample to view space (TBN is precomputed)
        float3 samplePos = fragPos + TBN * (ssaoKernel[i] * radius);
        
        // Project to screen space
        float4 offset = projection * float4(samplePos, 1.0);
        offset.xyz /= offset.w;  // perspective divide
        offset.xy = offset.xy * 0.5 + 0.5; // transform to 0.0 - 1.0
        offset.y = 1.0 - offset.y;
        
        // Sample depth at offset position
        float3 samplePosWS = positionMap.sample(s, offset.xy).xyz;
        float sampleDepth = (viewSpace * float4(samplePosWS, 1.0)).z;
        
        // Range check to reduce artifacts
        float range = max(abs(fragPosZ - sampleDepth), 0.0001);
        float rangeCheck = smoothstep(0.0, 1.0, radius / range);
        
        // Accumulate occlusion
        occlusion += (sampleDepth >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;
    }
    
    // Final occlusion value (inverted)
    occlusion = 1.0 - (occlusion * invKernelSize);
    
    return float4(occlusion, occlusion, occlusion, 1.0);
    
}


