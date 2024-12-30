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

vertex VertexCompositeOutput vertexCompositeShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentCompositeShader(VertexCompositeOutput vertexOut [[stage_in]],
                                        texture2d<float> finalTexture[[texture(0)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);

    float4 color=finalTexture.sample(s, vertexOut.uvCoords);

    return color;


}
