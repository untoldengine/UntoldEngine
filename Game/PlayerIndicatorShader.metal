//
//  PlayerIndicatorShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};


float2x2 scale(float2 _scale){
    return float2x2(_scale.x,0.0,
                0.0,_scale.y);
}

float sdTriangleIsos(float2 p, float2 q )
{
    p.x = abs(p.x);
    float2 a = p - q*clamp( dot(p,q)/dot(q,q), 0.0, 1.0 );
    float2 b = p - q*float2( clamp( p.x/q.x, 0.0, 1.0 ), 1.0 );
    float s = -sign( q.y );
    float2 d = min( float2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                  float2( dot(b,b), s*(p.y-q.y)  ));
    return -sqrt(d.x)*sign(d.y);
}


float sdfRing(float2 p, float2 c, float r)
{
    return abs(r - length(p - c));
}

float sdfCircle(float2 p,float r){

    return length(p)-r;
    
}

float _o(float2 uv) {
    return abs(length(float2(uv.x,max(0.,abs(uv.y)-.15)))-.25);
}

float _j(float2 uv) {
    uv.x+=.2;
    uv.y+=.55;
    float x = uv.x>0.&&uv.y<0.?
                abs(length(uv)-.25)
               :min(length(uv+float2(0.,.25)),
                    length(float2(uv.x-.25,max(0.,abs(uv.y-.475)-.475))));
    return x;
}

float _l(float2 uv) {
    uv.y -= .2;
    return length(float2(uv.x,max(0.,abs(uv.y)-.6)));
}

float _u(float2 uv, float w, float v) {
    return length(float2(
                abs(length(float2(uv.x,
                                max(0.0,-(.4-v)-uv.y) ))-w)
               ,max(0.,uv.y-.4)));
}

float SS(float2 uv) {
    uv.y -= .1;
    if (uv.y <.275-uv.x*.5 && uv.x>0. || uv.y<-.275-uv.x*.5)
        uv = -uv;
    float a = abs(length(float2(max(0.,abs(uv.x)),uv.y-.25))-.25);
    float b = length(float2(uv.x-.236,uv.y-.332));
    float x = atan2(uv.x-.05,uv.y-0.25)<1.14?a:b;
    return x;
}

float LL(float2 uv) {
    uv.y -=.1;
    float x = length(float2(max(0.,abs(uv.x)-.2),uv.y+.5));
    return min(x,length(float2(uv.x+.2,max(0.,abs(uv.y)-.5))));
}

float _11(float2 uv) {
    return min(min(
             sdfLine(uv,float2(-0.2,0.45),float2(0.,0.6)),
             length(float2(uv.x,max(0.,abs(uv.y-.1)-.5)))),
             length(float2(max(0.,abs(uv.x)-.2),uv.y+.4)));
             
}

float sdfCross( float2 p, float w, float r )
{
    p = abs(p);
    return length(p-min(p.x+p.y,w)*0.5) - r;
}



float PP(float2 uv) {
    float x = length(float2(
                abs(length(float2(max(0.0,uv.x),
                                 uv.y-.35))-0.25)
               ,min(0.,uv.x+.25)));
    return min(x,length(float2(uv.x+.25,max(0.,abs(uv.y-.1)-.5)) ));
}

float aa(float2 uv) {
    uv = -uv;
    float x = abs(length(float2(max(0.,abs(uv.x)-.05),uv.y-.2))-.2);
    x = min(x,length(float2(uv.x+.25,max(0.,abs(uv.y-.2)-.2))));
    return min(x,(uv.x<0.?uv.y<0.:atan2(uv.x,uv.y+0.15)>2.)?_o(uv):length(float2(uv.x-.22734,uv.y+.254)));
}

float ss(float2 uv) {
    if (uv.y <.225-uv.x*.5 && uv.x>0. || uv.y<-.225-uv.x*.5)
        uv = -uv;
    float a = abs(length(float2(max(0.,abs(uv.x)-.05),uv.y-.2))-.2);
    float b = length(float2(uv.x-.231505,uv.y-.284));
    float x = atan2(uv.x-.05,uv.y-0.2)<1.14?a:b;
    return x;
}

float hh(float2 uv) {
    uv.y *= -1.;
    float x = _u(uv,.25,.25);
    uv.x += .25;
    uv.y *= -1.;
    return min(x,_l(uv));
}

float oo(float2 uv) {
    return _o(uv);
}

float tt(float2 uv) {
    uv.x *= -1.;
    uv.y -= .4;
    uv.x += .05;
    float x = min(_j(uv),length(float2(max(0.,abs(uv.x-.05)-.25),uv.y)));
    return x;
}

float3 passText(float2 st,float2 resolution){

    st.y*=-1.0;
    
    float p=PP(st);
    
    p=sharpen(p,0.06,resolution);
    
    float3 color=float3(p);
    
    float a=aa(st-float2(0.7,0.0));
    
    a=sharpen(a,0.06,resolution);
    
    color=max(color,a);
    
    float s1=ss(st-float2(1.4,0.0));
    s1=sharpen(s1,0.06,resolution);
    color=max(color,s1);
    
    float s2=ss(st-float2(2.1,0.0));
    s2=sharpen(s2,0.06,resolution);
    color=max(color,s2);

    return color;
    
}

float3 shootText(float2 st, float2 resolution){

    st.y*=-1.0;
    
    float s=SS(st);
    s=sharpen(s,0.06,resolution);
    float3 color=max(color,s);
    
    float h=hh(st-float2(0.7,0.0));
    h=sharpen(h,0.06,resolution);
    
    color=max(color,float3(h));
    
    float o=oo(st-float2(1.4,0.0));
    o=sharpen(o,0.06,resolution);
    color=max(color,float3(o));

    float o2=oo(st-float2(2.1,0.0));
    o2=sharpen(o2,0.06,resolution);
    color=max(color,float3(o2));
    
    float t=tt(st-float2(2.8,0.0));
    t=sharpen(t,0.06,resolution);
    color=max(color,float3(t));
    
    return color;
    
}

float3 createCircle(float2 st, float2 resolution){

    float ring=sdfRing(st*4.0,float2(0.0,0.0),0.2);
    
    ring=sharpen(ring,0.015,resolution);
    
    float3 color=max(color,float3(ring)*float3(1.0,0.0,0.0));

    return color;
    
}

float3 createCross(float2 st, float2 resolution){

    float cross=sdfCross(st*40.0,2.0,0.1);
    cross=sharpen(cross,0.06,resolution);
    
    return float3(cross);

}

float3 createRing(float2 st, float2 resolution){

    float s=sdfRing(st*7.0,float2(0.0,0.0),0.25);
        
    s=sharpen(s,0.03,resolution);
    
    return float3(s)*float3(1.0);
    
}

vertex VertexOutput vertexIndicatorShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformGlobalData &uniformGlobalData [[buffer(2)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentIndicatorShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(0)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float2 st=-1. + 2. * vertexOut.uvCoords;
    
    float3 color =float3(0.0);
    
    //float playerDirection=sign(uniformShaderEntityProperty.shaderParameter[0].x);
    
    st*=3.0;
    
    st.x+=0.1;
    st.y+=0.7;
    
    float2 tST=st;
    
    tST=scale(float2(10.0,5.0))*tST;
    
    tST.y+=0.5;
    tST.x-=1.5;
    
    float t=sdfTriangle(tST*4.0);
    
    t=sharpen(t,0.06,uniformGlobalData.resolution);
    
    color=max(color,t)*float3(1.0,0.0,0.0);
    
    st.x+=0.1;

    color=max(color,createCircle(st,uniformGlobalData.resolution));

    color=max(color,createCross(st,uniformGlobalData.resolution));

    float2 passST=st;

    passST*=12.0;
    passST.x+=3.5;

    color=max(color,passText(passST,uniformGlobalData.resolution));

    st.y+=0.2;

    color=max(color,createCircle(st,uniformGlobalData.resolution));
    color=max(color,createRing(st,uniformGlobalData.resolution));

    float2 shootST=st;

    shootST*=12.0;
    shootST.x+=4.0;

    color=max(color,shootText(shootST,uniformGlobalData.resolution));
    
    return float4(color,1.0);
    
}




