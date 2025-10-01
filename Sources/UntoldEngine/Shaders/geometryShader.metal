//
//  geometryShader.metal
//  UntoldEngineRTX
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

using namespace metal;

vertex GeometryOutModel vertexGeometryShader(GeometryInModel in [[stage_in]],
                                          constant matrix_float4x4 &viewMatrix [[buffer((1))]],
                                          constant matrix_float4x4 &projectionMatrix [[buffer((2))]],
                                          constant matrix_float4x4 &modelMatrix [[buffer((3))]],
                                             constant simd_float3 &scale [[buffer(4)]]){

    GeometryOutModel out;
    matrix_float4x4 scaleMatrix = matrix_float4x4(scale.x,0.0,0.0,0.0,
                          0.0,scale.y,0.0,0.0,
                          0.0,0.0,scale.z,0.0,
                          0.0,0.0,0.0,1.0);
    
    float4 scaledPosition = scaleMatrix*in.position;
    
    
    out.position = projectionMatrix * viewMatrix * modelMatrix * scaledPosition;


    return out;
}

fragment float4 fragmentGeometryShader(VertexOutModel in [[stage_in]]){


    return float4(1.0,1.0,1.0,1.0);

}
