//
//  CompositeShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/22/23.
//

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
                                        texture2d<float> finalTexture[[texture(0)]],
                                        texture2d<float> gridTexture[[texture(1)]],
                                        depth2d<float> depthTexture [[texture(2)]],
                                        texture2d<float> gizmoTexture [[texture(3)]],
                                        constant bool &isGameMode [[ buffer(3) ]]){

    constexpr sampler s(min_filter::linear, mag_filter::linear);

    // Sample depth
    //float depth = depthTexture.sample(s, vertexOut.uvCoords);
    
    // Sample textures
    float4 gridColor = gridTexture.sample(s, vertexOut.uvCoords);
    float4 modelColor = finalTexture.sample(s, vertexOut.uvCoords);
    float lumen =getLuminance(modelColor.rgb);
    float blendFactor = (lumen == 0.0) ? 1.0 : 0.0;
    // Blend: show grid if there's no model
    float4 baseColor = mix(modelColor, gridColor, blendFactor);

    // Sample gizmo
    float3 gizmoColor = gizmoTexture.sample(s, vertexOut.uvCoords).rgb;
    float gizmoLumen = getLuminance(gizmoColor);

    if (!isGameMode && gizmoLumen > 0.1) {
        return float4(gizmoColor, 1.0);
    }

    return baseColor;
}
