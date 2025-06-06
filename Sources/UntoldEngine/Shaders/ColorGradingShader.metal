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

constant float LogC_cut = 0.011361;
constant float LogC_a = 5.555556;
constant float LogC_b = 0.047996;
constant float LogC_c = 0.244161;
constant float LogC_d = 0.386036;
constant float LogC_e = 5.301883;
constant float LogC_f = 0.092819;


float LinearToLogC(float x) {
    return (x > LogC_cut)
        ? LogC_c * log10(LogC_a * x + LogC_b) + LogC_d
        : LogC_e * x + LogC_f;
}

float3 LinearToLogC(float3 color) {
    return float3(
        LinearToLogC(color.r),
        LinearToLogC(color.g),
        LinearToLogC(color.b)
    );
}


float LogCToLinear(float y) {
    return (y > LinearToLogC(LogC_cut))
        ? (pow(10.0, (y - LogC_d) / LogC_c) - LogC_b) / LogC_a
        : (y - LogC_f) / LogC_e;
}

float3 LogCToLinear(float3 logColor) {
    return float3(
        LogCToLinear(logColor.r),
        LogCToLinear(logColor.g),
        LogCToLinear(logColor.b)
    );
}

float3 colorExposure(float3 color, float exposure){
    return color*exposure;
}

float3 colorContrast (float3 color, float contrast) {
    float ACEScc_MIDGRAY = 0.413588402;
    color = LinearToLogC(color);
    color = (color - ACEScc_MIDGRAY) * contrast + ACEScc_MIDGRAY;
    return LogCToLinear(color);
}


float3 colorSaturation(float3 color, float saturation) {
    float luminance = getLuminance(color);
    return (color - luminance) * saturation + luminance;
}

float3 LinearToLMS(float3 rgb) {
    return (float3x3(
         3.90405e-1, 5.49941e-1, 8.92632e-3,
         7.08416e-2, 9.63172e-1, 1.35775e-3,
         2.31082e-2, 1.28021e-1, 9.36245e-1
    )*rgb);
}

float3 LMSToLinear(float3 lms) {
    return (float3x3(
         2.85847e+0, -1.62879e+0, -2.48910e-2,
         -2.10182e-1,  1.15820e+0,  3.24281e-4,
         -4.18120e-2, -1.18169e-1,  1.06867e+0
    )*lms);
}

float3 whiteBalance(float3 color, float3 whiteBalanceCoeffs) {
    color = LinearToLMS(color);
    color *= whiteBalanceCoeffs;
    return LMSToLinear(color);
}


vertex VertexCompositeOutput vertexColorGradingShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentColorGradingShader(VertexCompositeOutput vertexOut [[stage_in]],
                                           texture2d<float> finalTexture [[texture(0)]],
                                           constant float &brightness [[buffer(colorGradingPassBrightnessIndex)]],
                                           constant float &contrast [[buffer(colorGradingPassContrastIndex)]],
                                           constant float &saturation [[buffer(colorGradingPassSaturationIndex)]],
                                           constant float &exposure [[buffer(colorGradingPassExposureIndex)]],
                                           constant float3 &whiteBalanceCoeffs[[buffer(colorGradingWhiteBalanceCoeffsIndex)]])
{
    constexpr sampler s(min_filter::linear, mag_filter::linear);
    float3 color = finalTexture.sample(s, vertexOut.uvCoords).rgb;

    color = colorExposure(color, exposure);
    color = whiteBalance(color, whiteBalanceCoeffs);
    color = colorContrast(color, contrast);
    color *= (1.0+brightness);
    color = colorSaturation(color, saturation);
    // Apply ACES Filmic Tone Mapping
    color.rgb = ACESFilmicToneMapping(color.rgb);
    return float4(max(color,0.0), 1.0);
}
