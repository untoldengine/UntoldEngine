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
                                        depth2d<float> depthTexture [[texture(2)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);

    float depth=depthTexture.sample(s, vertexOut.uvCoords);
    //if(depth==1.0) return gridTexture.sample(s, vertexOut.uvCoords);

    float4 color=finalTexture.sample(s, vertexOut.uvCoords);
    
    return color;
}
