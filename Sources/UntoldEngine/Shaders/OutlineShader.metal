//
//  File.metal
//  
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

vertex VertexOutOutline vertexOutlineShader( VertexInOutline in [[stage_in]], constant Uniforms &uniforms [[buffer(modelPassUniformIndex)]]) {

    VertexOutOutline out;
    float outlineWidth = 0.009;
    
    float4 position = in.position;
    float4 normals = in.normals;
   
    float4 worldPosition = uniforms.modelViewMatrix * position;
    
    worldPosition.xyz += normals.xyz * outlineWidth;
    
    out.position = uniforms.projectionMatrix * worldPosition;

    return out;
}

fragment float4 fragmentOutlineShader(VertexOutOutline in [[stage_in]]){
    return float4(1.0,1.0,1.0,1.0);
}
