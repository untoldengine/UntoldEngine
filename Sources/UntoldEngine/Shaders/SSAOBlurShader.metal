//
//  SSAOBlurShader.metal
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexSSAOBlurShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentSSAOBlurShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> ssaoTexture [[texture(0)]],
                                   constant bool &enabled[[buffer(0)]])
{
    constexpr sampler s(min_filter::linear, mag_filter::linear, mip_filter::linear,
                        s_address::clamp_to_edge, t_address::clamp_to_edge);
    if (!enabled){
        return float4(1.0);
    }
    
    uint width = ssaoTexture.get_width();
    uint height = ssaoTexture.get_height();
    float2 texelSize = 1.0 / float2(width, height);
   
    float result = 0.0;
    
    for(int x = -2; x < 2; ++x){
        for(int y = -2; y < 2; ++y){
            float2 sampleOffset = float2(float(x), float(y)) * texelSize;
            result += ssaoTexture.sample(s, vertexOut.uvCoords + sampleOffset).r;
        }
    }
    
    result = result/(4.0*4.0);
    
    return float4(result, result, result, 1.0);
    
}
