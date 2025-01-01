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

vertex VertexDebugOutput vertexDebugShader(VertexCompositeIn in [[stage_in]],
                                               constant int *viewportIndex[[buffer(5)]]){

    VertexDebugOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;
    vertexOut.viewport=viewportIndex[0];

    return vertexOut;
}

fragment float4 fragmentDebugShader(VertexDebugOutput vertexOut [[stage_in]],
                                    texture2d<float> finalTexture[[texture(0)]],
                                    depth2d<float> depthTexture [[texture(1)]],
                                    constant int &debugSelection [[buffer(2)]]){

    constexpr sampler s(min_filter::linear,mag_filter::linear);
    ushort2 texelCoordinates=ushort2(vertexOut.uvCoords.x*depthTexture.get_width(),vertexOut.uvCoords.y*depthTexture.get_height());


    if(vertexOut.viewport==3 && debugSelection == 0){
        return depthTexture.read(texelCoordinates);
    }

    return finalTexture.sample(s, vertexOut.uvCoords);

}
