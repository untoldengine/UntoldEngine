#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#include "../UntoldEngine4D/MetalShaders/U4DShaderProtocols.h"
#include "../UntoldEngine4D/MetalShaders/U4DShaderHelperFunctions.h"

#define M_PI 3.1415926535897932384626433832795

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};



float2x2 rotate2d(float _angle){
    return float2x2(cos(_angle),-sin(_angle),
                sin(_angle),cos(_angle));
}

float OO(float2 uv) {
    return abs(length(float2(uv.x,max(0.,abs(uv.y-.1)-.25)))-.25);
}

float EE(float2 uv) {
    uv.y -=.1;
    uv.y = abs(uv.y);
    float x = min(length(float2(max(0.,abs(uv.x)-.25),uv.y)),
                  length(float2(max(0.,abs(uv.x)-.25),uv.y-.5)));
    return min(x,length(float2(uv.x+.25,max(0.,abs(uv.y)-.5))));
}

float _o(float2 uv) {
    return abs(length(float2(uv.x,max(0.,abs(uv.y)-.15)))-.25);
}

float NN(float2 uv) {
    uv.y-=.1;
    float x = min(length(float2(uv.x-.25,max(0.,abs(uv.y)-.5))),
                  sdfLine(uv,float2(-.25,.5),float2(.25,-.5)));
    return min(x,length(float2(uv.x+.25,max(0.,abs(uv.y)-.5))));
}

float SS(float2 uv) {
    uv.y -= .1;
    if ((uv.y <.275-uv.x*.5 && uv.x>0.) || uv.y<-.275-uv.x*.5)
        uv = -uv;
    float a = abs(length(float2(max(0.,abs(uv.x)),uv.y-.25))-.25);
    float b = length(float2(uv.x-.236,uv.y-.332));
    float x = atan2(uv.x-.05,uv.y-0.25)<1.14?a:b;
    return x;
}

float WW(float2 uv) {
    uv.x=abs(uv.x);
    return min(sdfLine(uv,float2(0.3,0.6), float2(.2,-0.4)),
               sdfLine(uv,float2(0.2,-0.4), float2(0.,0.2)));
}

//This is the function responsible for the rendering of the navigation hud.
float3 navHud(float2 st,float2 resolution, float data, int showText){

    float3 color=float3(0.0);
    float2 stm=st;
    
    st*=6.0;
    st.x+=data;
    float2 fid=fract(st);
    float2 iid=floor(st);
    
    float b=sdfBox(stm-float2(0.0,0.5),float2(.5,0.5));

    b=sharpen(b,0.01,resolution);
//
//    color=float3(b);
    
    //select the upper grid
    if( iid.y==5.0){
        
        //Make the compass lines
        float2 fid2=fract(st+float2(0.5,0.0));
        
        float compassLines=step(0.9,fid2.x);
        
        //get every fourth grid
        float t=mod(iid.x,4.0);
        
        //if mod is not 0, make the lines shorter
        if(t!=0){
            
            //multiply line by the step function.
            compassLines*=step(0.3,fid2.y*0.6);
            
        }
        
        color=max(color,float3(compassLines));
    
    }else if(iid.y==4 && showText==1){
    
        float f=mod(iid.x,16);

        if(f==0){
            //render the N letter
            float n=NN(fid*2.5-float2(1.0,1.0));
            n=1.0-step(0.03,n);

            color+=float3(n);
        }else if(f==4){
            //render the E
            float e=EE(fid*2.5-float2(1.0,1.0));
            e=1.0-step(0.03,e);

            color+=float3(e);
        }else if(f==8){
            //render the S
            float s=SS(fid*2.5-float2(1.0,1.0));
            s=1.0-step(0.03,s);

            color+=float3(s);
        }else if(f==12){

            //render the W
            float w=WW(fid*2.5-float2(1.0,1.0));
            w=1.0-step(0.03,w);

            color+=float3(w);
        }
        
    }
    
    
    color=min(color,float3(b));
    
    return color;
}




float3 crossHair(float2 st, float2 resolution){

    float3 color=float3(0.0);
    st.y+=0.05;
    float ring=sdfRing(st*20.0,float2(0.0),0.5);
    
    ring=sharpen(ring,0.06,resolution);
    
    color=float3(ring);
    
    float m=0.0;
    
    for(int i=0;i<4;i++){
    
        st=rotate2d(i*90.0*M_PI/180.0)*st;
    
        float l=sdfLine(st,float2(0.025,0.0),float2(0.05,0.0));
    
    l=sharpen(l,0.001,resolution);
    
    m+=l;
    }
    
    
    color=max(color,float3(m));
    
    return color;

}

vertex VertexOutput vertexNavShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(viSpaceBuffer)]], constant UniformGlobalData &uniformGlobalData [[buffer(viGlobalDataBuffer)]], uint vid [[vertex_id]]){
    
    VertexOutput vertexOut;
    
    vertexOut.uvCoords=vert.uv;
    
    float4 position=uniformSpace.modelViewProjectionSpace*float4(vert.position);
    
    vertexOut.position=position;
    
    return vertexOut;
}

fragment float4 fragmentNavShader(VertexOutput vertexOut [[stage_in]], constant UniformGlobalData &uniformGlobalData [[buffer(fiGlobalDataBuffer)]], constant UniformShaderEntityProperty &uniformShaderEntityProperty [[buffer(fiShaderEntityPropertyBuffer)]], texture2d<float> texture[[texture(fiTexture0)]], sampler sam [[sampler(fiSampler0)]]){
    
    float2 st = -1. + 2. * vertexOut.uvCoords;
    st.y*=-1.0;
    
    float3 color=float3(0.0);
    
    float3 yaw=navHud(st+float2(0.0,0.2),uniformGlobalData.resolution,uniformShaderEntityProperty.shaderParameter[0].x/22.5,1.0);
    
    color=yaw;
    
    
    //if(fid.x>0.95 || fid.y>0.95) color.r=1.0;

    st.y+=0.8;
    float3 cHair=crossHair(st,uniformGlobalData.resolution);
    
    //color=max(color,cHair);
    
    return float4(color,1.0);
}


