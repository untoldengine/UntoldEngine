//
//  ColorGradingShader.metal
//
//
//  Created by Harold Serrano on 5/25/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexColorGradingShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentColorGradingShader(VertexCompositeOutput vertexOut [[stage_in]],
                                        texture2d<float> finalTexture[[texture(0)]],
                                        constant float &brightness[[buffer(colorGradingPassBrightnessIndex)]],
                                        constant float &contrast[[buffer(colorGradingPassContrastIndex)]],
                                        constant float &saturation[[buffer(colorGradingPassSaturationIndex)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);
    
    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;

    // Apply brightness
    color += brightness;

    // Apply contrast (centered around 0.5 to preserve midtones)
    color = (color - 0.5) * contrast + 0.5;

    // Apply saturation
    float luminance = dot(color, float3(0.299, 0.587, 0.114)); // Luma approximation
    color = mix(float3(luminance), color, saturation);

    return float4(clamp(color, 0.0, 1.0), 1.0);

}



