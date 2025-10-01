//
//  ChromaticShader.metal
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

vertex VertexCompositeOutput vertexChromaticAberrationShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

fragment float4 fragmentChromaticAberrationShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                    constant float &intensity [[buffer(chromaticAberrationPassIntensityIndex)]],
                                    constant simd_float2 &center[[buffer(chromaticAberrationPassCenterIndex)]],
                                                  constant bool &enabled[[buffer(chromaticAberrationPassEnabledIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);
    
    float2 uv = vertexOut.uvCoords;
   
    if (!enabled){
        return finalTexture.sample(s, uv);
    }
    
    float2 offset = normalize(uv - center) * intensity;

    float red   = finalTexture.sample(s, uv + offset).r;
    float green = finalTexture.sample(s, uv).g;
    float blue  = finalTexture.sample(s, uv - offset).b;

    return float4(red, green, blue, 1.0);
}



