//
//  SSAOShader.metal
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
    // Base Color and Normal Maps: Linear filtering, mipmaps, repeat wrapping
    constexpr sampler s(min_filter::linear, mag_filter::linear, mip_filter::linear,
                        s_address::clamp_to_edge, t_address::clamp_to_edge);
    
    constexpr sampler normalSampler(min_filter::linear, mag_filter::linear, mip_filter::linear,
                                    s_address::clamp_to_edge, t_address::clamp_to_edge);

    float2 noiseScale = float2(viewPort.x/4.0, viewPort.y/4.0);
    
    float3 worldPos = positionMap.sample(s, vertexOut.uvCoords).xyz;
    float3 fragPos = (viewSpace * float4(worldPos, 1.0)).xyz;

    float3 normalWS = normalMap.sample(normalSampler, vertexOut.uvCoords).xyz;

    // Extract the 3x3 portion of the view matrix manually
    float3x3 view3x3 = float3x3(viewSpace.columns[0].xyz,
                                viewSpace.columns[1].xyz,
                                viewSpace.columns[2].xyz);

    float3 normal = normalize(view3x3 * normalWS);


    float3 randomVec = ssaoNoiseMap.sample(s, vertexOut.uvCoords * noiseScale).xyz;
    
    float3 tangent = normalize(randomVec - normal * dot(randomVec, normal));
    float3 bitangent = cross(normal, tangent);
    float3x3 TBN = float3x3(tangent, bitangent, normal);
    
    float occlusion = 0.0;
    //float radius = 0.5;
    //float bias = 0.0025;
    for(int i=0; i<kernelSize; ++i){
        //get sample position
        float3 samplePos = TBN * ssaoKernel[i]; // tanget to view space
        samplePos = fragPos.xyz + samplePos*radius;
        
        float4 offset = float4(samplePos,1.0);
        //offset.y = 1.0 - offset.y;
        offset = projection * offset;  // view to clip space
        offset.xyz /= offset.w;        // perspective divide
        offset.xyz = offset.xyz * 0.5 + 0.5; // transform to 0.0 - 1.0
        offset.y = 1.0 - offset.y;
        float3 samplePosWS = positionMap.sample(s, offset.xy).xyz;
        float sampleDepth = (viewSpace * float4(samplePosWS, 1.0)).z;

        float range = max(abs(fragPos.z - sampleDepth), 0.0001);
        float rangeCheck = smoothstep(0.0, 1.0, radius / range);

        occlusion += (sampleDepth >= samplePos.z + bias ? 1.0 : 0.0) * rangeCheck;

    }
    
    occlusion = 1.0 - (occlusion/kernelSize);
    
    if (!enabled){
        return float4(1.0,1.0,1.0, 1.0);
    }
    
    return float4(occlusion, occlusion, occlusion, 1.0);
    
}


