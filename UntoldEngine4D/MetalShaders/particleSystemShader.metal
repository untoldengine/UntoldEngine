//
//  particleShader.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
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

float2 hash( float2 x );
float noise(float2 p, float noiseDetail );

vertex VertexOutput vertexParticleSystemShader(VertexInput vert [[stage_in]], constant UniformSpace *uniformSpace [[buffer(1)]], constant UniformParticleProperty *uniformParticleProperty [[buffer(2)]], uint vid [[vertex_id]], ushort iid [[instance_id]]){
    
    VertexOutput vertexOut;
    
    float scaleFactor=uniformParticleProperty[iid].scaleFactor;
    float rotationAngle=uniformParticleProperty[iid].rotationAngle;
    
    float4x4 scaleMatrix=float4x4(scaleFactor,0.0,0.0,0.0,
                                  0.0,scaleFactor,0.0,0.0,
                                  0.0,0.0,scaleFactor,0.0,
                                  0.0,0.0,0.0,1.0);
    
    float4x4 rotationMatrix=float4x4(cos(rotationAngle),-sin(rotationAngle),0.0,0.0,
                                     sin(rotationAngle),cos(rotationAngle),0.0,0.0,
                                     0.0,0.0,0.0,0.0,
                                     0.0,0.0,0.0,1.0);
    
    float4 transformedVertices=rotationMatrix*vert.position;
    
    transformedVertices=scaleMatrix*transformedVertices;
    
    float4 position=uniformSpace[iid].modelViewProjectionSpace*transformedVertices;

    vertexOut.position=position;
    vertexOut.color=uniformParticleProperty[iid].color;
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

//The following is a Perlin noise function. It is explained here http://mrl.nyu.edu/~perlin/noise/ and here http://mrl.nyu.edu/~perlin/paper445.pdf
//The implementation was gotten from here https://www.shadertoy.com/view/XdXGW8. I did minor changes such as use the improved fade function mentioned
//by Perlin

float2 hash( float2 x )
{
    const float2 k = float2( 0.3183099, 0.3678794 );
    x = x*k + k.yx;
    return -1.0 + 2.0*fract( 16.0 * k*fract( x.x*x.y*(x.x+x.y)) );
}

float noise(float2 p, float noiseDetail )
{
    p*=noiseDetail;
    
    float2 i = floor( p );
    float2 f = fract( p );
    
    //improved fade function
    float2 u=f*f*f*(6.0*f*f-15.0*f+10.0);
    
    return (mix( mix( dot( hash( i + float2(0.0,0.0) ), f - float2(0.0,0.0) ),
                     dot( hash( i + float2(1.0,0.0) ), f - float2(1.0,0.0) ), u.x),
                mix( dot( hash( i + float2(0.0,1.0) ), f - float2(0.0,1.0) ),
                    dot( hash( i + float2(1.0,1.0) ), f - float2(1.0,1.0) ), u.x), u.y))*0.5+0.5;
    
    
}
