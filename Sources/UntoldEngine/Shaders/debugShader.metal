//
//  debugShader.metal
//  UntoldShadersKernels
//
//  Created by Harold Serrano on 2/11/24.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
using namespace metal;

vertex VertexDebugOutput vertexDebugShader(VertexCompositeIn in [[stage_in]]){

    VertexDebugOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment float4 fragmentDebugShader(VertexDebugOutput vertexOut [[stage_in]],
                                    texture2d<float> finalTexture[[texture(0)]],
                                    constant int &debugSelection [[buffer(2)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);

    return finalTexture.sample(s, vertexOut.uvCoords);

}
