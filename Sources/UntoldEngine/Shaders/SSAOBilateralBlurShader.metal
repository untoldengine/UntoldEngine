//
//  SSAOBilateralBlurShader.metal
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

vertex VertexCompositeOutput vertexSSAOBilateralBlurShader(VertexCompositeIn in [[stage_in]]) {
    VertexCompositeOutput vertexOut;
    vertexOut.position = float4(float3(in.position), 1.0);
    vertexOut.uvCoords = in.uvCoords;
    return vertexOut;
}

// Separable bilateral blur for SSAO
// This is much faster than the box blur (2 passes of 5 taps vs 1 pass of 16 taps)
fragment float4 fragmentSSAOBilateralBlurShader(VertexCompositeOutput vertexOut [[stage_in]],
                                                texture2d<float> ssaoTexture [[texture(0)]],
                                                texture2d<float> depthTexture [[texture(1)]],
                                                constant float2 &blurDirection [[buffer(0)]],
                                                constant bool &enabled [[buffer(1)]])
{
    if (!enabled) {
        return float4(1.0);
    }
    
    constexpr sampler s(min_filter::nearest, mag_filter::nearest, 
                        s_address::clamp_to_edge, t_address::clamp_to_edge);
    
    uint width = ssaoTexture.get_width();
    uint height = ssaoTexture.get_height();
    float2 texelSize = 1.0 / float2(width, height);
    
    // Sample center
    float centerAO = ssaoTexture.sample(s, vertexOut.uvCoords).r;
    float centerDepth = depthTexture.sample(s, vertexOut.uvCoords).r;
    
    // Bilateral blur parameters
    const int kernelRadius = 2;
    const float depthSigma = 0.015; // Depth sensitivity
    const float spatialSigma = 2.0; // Spatial falloff
    
    float totalWeight = 1.0;
    float result = centerAO;
    
    // Separable blur in specified direction (horizontal or vertical)
    for (int i = 1; i <= kernelRadius; ++i) {
        float2 offset = blurDirection * texelSize * float(i);
        
        // Sample both sides
        float2 uvPlus = vertexOut.uvCoords + offset;
        float2 uvMinus = vertexOut.uvCoords - offset;
        
        float aoPlus = ssaoTexture.sample(s, uvPlus).r;
        float aoMinus = ssaoTexture.sample(s, uvMinus).r;
        
        float depthPlus = depthTexture.sample(s, uvPlus).r;
        float depthMinus = depthTexture.sample(s, uvMinus).r;
        
        // Compute depth-aware weights
        float depthDiffPlus = abs(centerDepth - depthPlus);
        float depthDiffMinus = abs(centerDepth - depthMinus);
        
        float weightPlus = exp(-depthDiffPlus / depthSigma) * exp(-float(i * i) / spatialSigma);
        float weightMinus = exp(-depthDiffMinus / depthSigma) * exp(-float(i * i) / spatialSigma);
        
        result += aoPlus * weightPlus + aoMinus * weightMinus;
        totalWeight += weightPlus + weightMinus;
    }
    
    result /= totalWeight;
    
    return float4(result, result, result, 1.0);
}
