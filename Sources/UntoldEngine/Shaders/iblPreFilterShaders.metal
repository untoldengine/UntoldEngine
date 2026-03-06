//
//  iblPreFilterShaders.metal
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
