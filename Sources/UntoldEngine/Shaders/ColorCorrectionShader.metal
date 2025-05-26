//
//  ColorCorrectionShader.metal
//  
//
//  Created by Harold Serrano on 5/26/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexColorCorrectionShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentColorCorrectionShader(VertexCompositeOutput vertexOut [[stage_in]],
                                        texture2d<float> finalTexture[[texture(0)]],
                                        constant float &temperature[[buffer(colorCorrectionPassTemperatureIndex)]],
                                        constant float &tint[[buffer(colorCorrectionPassTintIndex)]],
                                        constant simd_float3 &lift[[buffer(colorCorrectionPassLiftIndex)]],
                                              constant simd_float3 &gamma[[buffer(colorCorrectionPassGammaIndex)]],
                                              constant simd_float3 &gain[[buffer(colorCorrectionPassGainIndex)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);
    
    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;
    
    // --- White Balance (Temperature & Tint) ---
    float3 whiteBalance = float3(
        1.0 + temperature - tint,
        1.0,
        1.0 - temperature - tint
    );
    color *= whiteBalance;

    // --- Lift (Shadows Adjustment) ---
    color = color + lift;

    // --- Gamma (Midtones Adjustment) ---
    color = pow(color, gamma);

    // --- Gain (Highlights Scaling) ---
    color *= gain;

    return float4(clamp(color, 0.0, 1.0), 1.0);
    
}

