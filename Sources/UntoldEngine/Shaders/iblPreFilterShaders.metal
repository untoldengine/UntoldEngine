//
//  iblPreFilterShaders.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/26/23.
//  For more information on how these shaders work, please see:
// https://www.mathematik.uni-marburg.de/~thormae/lectures/graphics1/graphics_10_2_eng_web.html#45

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
using namespace metal;

vertex VertexCompositeOutput vertexIBLPreFilterShader(VertexCompositeIn in [[stage_in]]){

    VertexCompositeOutput vertexOut;
    vertexOut.position=float4(float3(in.position),1.0);
    vertexOut.uvCoords=in.uvCoords;

    return vertexOut;
}

fragment IBLFragmentOut fragmentIBLPreFilterShader(VertexCompositeOutput in [[stage_in]],
                                        texture2d<float> environmentTexture[[texture(0)]]){


//    constexpr sampler s(coord::normalized,
//                        filter::linear,
//                        mip_filter::linear,
//                        address::repeat);

    IBLFragmentOut out;

    out.irradiance=diffuseImportanceMap(in.uvCoords, environmentTexture);
    out.specular=specularImportanceMap(in.uvCoords, environmentTexture);
    out.brdfMap=BRDFIntegrationMap(1.0-in.uvCoords.y, in.uvCoords.x);

    return out;
}
