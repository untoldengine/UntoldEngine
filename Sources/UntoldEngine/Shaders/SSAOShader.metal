//
//  SSAOShader.metal
//
//
//  Created by Harold Serrano on 5/30/25.
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
                                   texture2d<float> finalTexture [[texture(0)]],
                                   constant float &radius [[buffer(ssaoPassRadiusIndex)]],
                                   constant float &bias [[buffer(ssaoPassBiasIndex)]],
                                   constant float &intensity[[buffer(ssaoPassIntensityIndex)]],
                                   constant bool &enabled[[buffer(ssaoPassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);

    if (!enabled){
        return finalTexture.sample(s, vertexOut.uvCoords);
    }
    
    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;

    return float4(color, 1.0);
    
}


