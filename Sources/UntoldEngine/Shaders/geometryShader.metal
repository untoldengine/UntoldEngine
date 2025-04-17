//
//  geometryShader.metal
//  UntoldEngineRTX
//
//  Created by Harold Serrano on 5/26/24.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

using namespace metal;

vertex GeometryOutModel vertexGeometryShader(GeometryInModel in [[stage_in]],
                                          constant matrix_float4x4 &viewMatrix [[buffer((1))]],
                                          constant matrix_float4x4 &projectionMatrix [[buffer((2))]],
                                          constant matrix_float4x4 &modelMatrix [[buffer((3))]]){

    GeometryOutModel out;

    out.position = projectionMatrix * viewMatrix * modelMatrix * in.position;


    return out;
}

fragment float4 fragmentGeometryShader(VertexOutModel in [[stage_in]]){


    return float4(1.0,1.0,1.0,1.0);

}
