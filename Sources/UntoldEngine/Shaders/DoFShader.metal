//
//  DoFShader.metal
//  
//
//  Created by Harold Serrano on 5/29/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexDepthOfFieldShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

float computeBlurAmount(float depth, float focusDistance, float focusRange) {
    float blur = abs(depth - focusDistance) / focusRange;
    return clamp(blur, 0.0, 1.0);
}

fragment float4 fragmentDepthOfFieldShader(VertexCompositeOutput vertexOut [[stage_in]],
                                   texture2d<float> finalTexture [[texture(0)]],
                                   depth2d<float> depthTexture [[texture(1)]],
                                   constant float &focusDistance[[buffer(depthOfFieldPassFocusDistanceIndex)]],
                                   constant float &focusRange[[buffer(depthOfFieldPassFocusRangeIndex)]],
                                   constant float &maxBlur[[buffer(depthOfFieldPassMaxBlurIndex)]])
{
    constexpr sampler s(address::clamp_to_edge, min_filter::linear, mag_filter::linear);
    ushort2 texelCoordinates=ushort2(vertexOut.uvCoords.x*depthTexture.get_width(),vertexOut.uvCoords.y*depthTexture.get_height());
    
    // Get scene depth at this pixel
    float sceneDepth = depthTexture.read(texelCoordinates);

    // Compute blur factor
    float blurFactor = computeBlurAmount(sceneDepth, focusDistance, focusRange);

    // Sample neighborhood in a circular pattern
    float4 color = float4(0.0);
    int samples = 8;
    float radius = blurFactor * maxBlur;

    for (int i = 0; i < samples; ++i) {
        float angle = float(i) / samples * 2.0 * M_PI_F;
        float2 offset = float2(cos(angle), sin(angle)) * radius;
        color += finalTexture.sample(s, vertexOut.uvCoords + offset);
    }

    color /= samples;
    return color;
}

