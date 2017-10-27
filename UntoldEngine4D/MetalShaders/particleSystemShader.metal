//
//  particleShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include "U4DShaderProtocols.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

float3 hash3( float2 p );
float noise( float2 uv, float detail);

vertex VertexOutput vertexParticleSystemShader(VertexInput vert [[stage_in]], constant UniformSpace *uniformSpace [[buffer(1)]], constant UniformParticleProperty *uniformParticleProperty [[buffer(2)]], uint vid [[vertex_id]], ushort iid [[instance_id]]){
    
    VertexOutput vertexOut;
    
    float4 position=uniformSpace[iid].modelViewProjectionSpace*vert.position;

    vertexOut.position=position;
    vertexOut.color=float4(uniformParticleProperty[iid].color,1.0);
    vertexOut.uvCoords=vert.uv;
    
    
    return vertexOut;
}

fragment float4 fragmentParticleSystemShader(VertexOutput vertexOut [[stage_in]], constant UniformParticleSystemProperty &uniformParticleSystemProperty [[buffer(0)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float4 sampledColor;
    
    if(uniformParticleSystemProperty.hasTexture){
        
        sampledColor=texture.sample(sam,vertexOut.uvCoords);

        if(uniformParticleSystemProperty.enableNoise){
            
            sampledColor=sampledColor*noise(vertexOut.uvCoords, uniformParticleSystemProperty.noiseDetail)*vertexOut.color;
            
        }else{
            sampledColor=sampledColor*vertexOut.color;
        }
        
    }else{
        sampledColor=vertexOut.color;
    }
    
    return sampledColor;
    
}

float3 hash3( float2 p )
{
    float3 q = float3( dot(p,float2(127.1,311.7)),
                  dot(p,float2(269.5,183.3)),
                  dot(p,float2(419.2,371.9)) );
    return fract(sin(q)*43758.5453);
}

float noise( float2 uv, float detail)
{
    
    
    float2 x=float2(detail*uv.x,detail*uv.y);
    
    float u=0.0;
    float v=1.0;
    
    float2 p = floor(x);
    float2 f = fract(x);
    
    float k = 1.0+63.0*pow(1.0-v,4.0);
    
    float va = 0.0;
    float wt = 0.0;
    for( int j=-2; j<=2; j++ )
        for( int i=-2; i<=2; i++ )
        {
            float2 g = float2( float(i),float(j) );
            float3 o = hash3( p + g )*float3(u,u,1.0);
            float2 r = g - f + o.xy;
            float d = dot(r,r);
            float ww = pow( 1.0-smoothstep(0.0,1.414,sqrt(d)), k );
            va += o.z*ww;
            wt += ww;
        }
    
    return va/wt;
}

