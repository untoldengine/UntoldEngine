//
//  File.metal
//  
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
using namespace metal;


vertex LightVisualOutModel vertexLightVisualShader(LightVisualInModel in [[stage_in]],
                                             constant float4x4 &viewMatrix [[buffer(lightVisualPassViewMatrixIndex)]],
                                             constant float4x4 &projectionMatrix [[buffer(lightVisualPassProjMatrixIndex)]],
                                             constant float4x4 &modelMatrix [[buffer(lightVisualPassModelMatrixIndex)]]) {

    LightVisualOutModel out;

    // Extract camera orientation from view matrix
    float3 right   = float3(viewMatrix[0][0], viewMatrix[1][0], viewMatrix[2][0]); // camera right
    float3 up      = float3(viewMatrix[0][1], viewMatrix[1][1], viewMatrix[2][1]); // camera up

    float2 scale = float2(0.1);
    
    // Position in world space
    float3 center = float3(modelMatrix[3].xyz); // get the translation of the model
    float3 localPos = float3(in.position.x*scale.x, in.position.y*scale.y, in.position.z);

    // Reconstruct billboard vertex position in world space
    float3 billboardWorldPos = center + (right * localPos.x) + (up * localPos.y);

    float4 worldPosition = float4(billboardWorldPos, 1.0);

    // Project to clip space
    out.position = projectionMatrix * viewMatrix * worldPosition;
    out.uvCoords = in.uv;
    return out;
}

fragment float4 fragmentLightVisualShader(LightVisualOutModel in [[stage_in]], texture2d<float> lightTexture [[texture(0)]]) {
    
    constexpr sampler s(min_filter::nearest,mag_filter::nearest,s_address::repeat, t_address::repeat);
    float2 st = in.uvCoords;
    //st.y=1.0-st.y;
    
    float4 inBaseColor = lightTexture.sample(s, st);
    if(inBaseColor.a < 0.5){
        discard_fragment();
    }
    return inBaseColor; // White color
}
