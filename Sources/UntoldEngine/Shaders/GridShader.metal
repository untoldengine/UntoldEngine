//
//  GridShader.metal
//  UntoldEngine3D
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include <simd/simd.h>

using namespace metal;



struct VertexInput {

    float3    position [[ attribute(0) ]];

};

struct VertexOutput{

    float4 position [[position]];
    float3 nearPoint;
    float3 farPoint;
    float4 color;
};

struct FragmentOut{
    float4 color;
    float depth [[depth(any)]];
};

//This shader creates an infinite grid. The steps were followed from this post: http://asliceofrendering.com/scene%20helper/2020/01/05/InfiniteGrid/

//Grid position are in xy clipped space
//constant float3 gridPlane[6]={float3(1.0,1.0,0.0),float3(-1.0,-1.0,0.0),float3(-1.0,1.0,0.0),
//    float3(-1.0,-1.0,0.0),float3(1.0,1.0,0.0),float3(1.0,-1.0,0.0)};

float3 unprojectPoint(float x, float y, float z, float4x4 uView, float4x4 uProjection){

    //get to clip space
    //for and explanation check this illustration: https://antongerdelan.net/opengl/raycasting.html
    float4 unprojPoint=uView*uProjection*float4(x,y,z,1.0);
    return unprojPoint.xyz/unprojPoint.w;
}

// vpMatrix must be the forward P*V transform (stored in uniformSpace.modelViewMatrix).
float computeDepth(float3 pos, float4x4 vpMatrix){
    float4 clipSpacePos = vpMatrix * float4(pos.xyz, 1.0);
    return clipSpacePos.z / clipSpacePos.w;
}

float4 computeGrid(float3 uFragPos,float uScale){

    float2 coord=uFragPos.xz*uScale;

    float2 derivative=fwidth(coord);
    float2 grid=abs(fract(coord-0.5)-0.5)/derivative;
    float line=min(grid.x, grid.y);
    float minimumz=min(derivative.y, 1.0);
    float minimumx=min(derivative.x,1.0);

    float4 color=float4(0.2,0.2,0.2,1.0-min(line,1.0));

    //z-axis
    if(uFragPos.x>-minimumx && uFragPos.x<minimumx) color.z=1.0;

    //x-axis
    if(uFragPos.z>-minimumz && uFragPos.z<minimumz) color.x=1.0;

    return color;
}

// Computes normalized [0,1] distance from the camera to pos, independent of Z convention.
// uInvView must be V^{-1} (stored in uniformSpace.viewMatrix); its translation column is the camera world position.
float computeLinearDepth(float3 pos, float far, float4x4 uInvView){
    float3 cameraPos = (uInvView * float4(0.0, 0.0, 0.0, 1.0)).xyz;
    return length(pos - cameraPos) / far;
}



vertex VertexOutput vertexGridShader(VertexInput vert [[stage_in]], constant Uniforms &uniformSpace [[buffer(gridPassUniformIndex)]], uint vid [[vertex_id]]){

    VertexOutput vertexOut;

    float4 p=float4(vert.position,1.0);

    // Reverse-Z: NDC z=1 is the near plane, z=0 is the far plane (opposite of the usual
    // forward-Z convention), so the near/far unprojection depths below are swapped to match.
    float3 nearPoint=unprojectPoint(p.x, p.y, 1.0, uniformSpace.viewMatrix, uniformSpace.projectionMatrix).xyz;

    float3 farPoint=unprojectPoint(p.x, p.y, 0.0,uniformSpace.viewMatrix, uniformSpace.projectionMatrix).xyz;

    vertexOut.position=p;
    vertexOut.nearPoint=nearPoint;
    vertexOut.farPoint=farPoint;

    return vertexOut;
}

fragment FragmentOut fragmentGridShader(VertexOutput vertexOut [[stage_in]], constant Uniforms &uniformSpace [[buffer(gridPassUniformIndex)]]){

    FragmentOut finalColor;

    float far=100.0;

    float t=-vertexOut.nearPoint.y/(vertexOut.farPoint.y-vertexOut.nearPoint.y);

    float3 fragPosition=vertexOut.nearPoint+t*(vertexOut.farPoint-vertexOut.nearPoint);

    // modelViewMatrix holds the forward P*V matrix for correct depth in any Z convention.
    finalColor.depth=clamp(computeDepth(fragPosition, uniformSpace.modelViewMatrix),0.0,1.0);

    float linearDepth=computeLinearDepth(fragPosition, far, uniformSpace.viewMatrix);

    float fading=max(0.0, (0.5-linearDepth));

    finalColor.color=(computeGrid(fragPosition, 5.0)+computeGrid(fragPosition, 1.0))*float(t>0);

    finalColor.color.a*=fading;
    //finalColor.color = float4(0.2235,0.2235,0.2235,1.0);
    return finalColor;

}
