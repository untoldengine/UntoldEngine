//
//  CompositeShader.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexCompositeOutput vertexPreCompositeShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentPreCompositeShader(VertexCompositeOutput vertexOut [[stage_in]],
                                        texture2d<float> finalTexture[[texture(prePassFinalTextureIndex)]],
                                        texture2d<float> envTexture[[texture(prePassEnvTextureIndex)]],
                                        depth2d<float> depthTexture [[texture(prePassDepthTextureIndex)]],
                                        texture2d<float> gizmoTexture [[texture(prePassGizmoTextureIndex)]],
                                        texture2d<float> gaussianTexture [[texture(prePassGaussianTextureIndex)]],
                                        texture2d<float> ssaoTexture [[texture(prePassSSAOTextureIndex)]],
                                        constant bool &isGameMode [[ buffer(prePassGizmoBufferIndex) ]],
                                        constant bool &isPassthrough [[buffer(prePassPassthroughBufferIndex)]],
                                        constant bool &ssaoEnabled [[buffer(prePassSSAOEnabledIndex)]]) {

    constexpr sampler s(min_filter::linear, mag_filter::linear);

    // Sample textures
    float4 envColor = envTexture.sample(s, vertexOut.uvCoords);
    float4 modelColor = finalTexture.sample(s, vertexOut.uvCoords);
    float4 gaussianColor = gaussianTexture.sample(s, vertexOut.uvCoords);

    if (ssaoEnabled) {
        float ao = ssaoTexture.sample(s, vertexOut.uvCoords).r;
        modelColor.rgb *= ao;
    }
    
    // Composite scene color over environment using alpha.
    // This guarantees transparent pixels blend against environment instead of black.
    float4 background = (isPassthrough == false) ? envColor : float4(0.0, 0.0, 0.0, 0.0);
    float4 baseColor = modelColor + background * (1.0 - modelColor.a);
    
    // Composite Gaussians (occlusion handled during Gaussian rendering)
    baseColor.rgb = gaussianColor.rgb + baseColor.rgb * (1.0 - gaussianColor.a);
    baseColor.a = gaussianColor.a + baseColor.a * (1.0 - gaussianColor.a);

    // Non-passthrough modes (full immersion, macOS, AR) present an opaque layer:
    // the environment already fills every background pixel, so alpha must be 1.0
    // regardless of what upstream content (HDR alpha, material alpha, Gaussians)
    // produced. Only mixed passthrough is allowed to punch through via alpha.
    if (isPassthrough == false) {
        baseColor.a = 1.0;
    }

    // Sample gizmo
    float3 gizmoColor = gizmoTexture.sample(s, vertexOut.uvCoords).rgb;
    float gizmoLumen = getLuminance(gizmoColor);

    if (!isGameMode && gizmoLumen > 0.1) {
        return float4(gizmoColor, 1.0);
    }

    return baseColor;
}
