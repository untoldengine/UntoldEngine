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
    float transperancy;
    
};

vertex VertexOutput vertexParticleShader(VertexInput vert [[stage_in]], constant UniformSpace &uniformSpace [[buffer(1)]], constant UniformParticleInstanceProperty *uniformParticleInstanceProperty [[buffer(2)]], constant UniformParticleAnimation &uniformParticleAnimation [[buffer(3)]], constant UniformParticleProperty &uniformParticleProperty [[buffer (4)]], uint vid [[vertex_id]], ushort iid [[instance_id]]){
    
    VertexOutput vertexOut;
    
    //vertexOut.uvCoords=vert.uv;
    
    float4 particleVert=float4(0.0,0.0,0.0,0.0);
    float transperancy=1.0;
    
    if(uniformParticleAnimation.time>uniformParticleInstanceProperty[iid].time){
        
        particleVert=float4(vert.position)+float4(uniformParticleInstanceProperty[iid].velocity*uniformParticleAnimation.time,0.0);
        transperancy=1.0-uniformParticleAnimation.time/uniformParticleProperty.particleLifeTime;
    }
    
    float4 position=uniformSpace.modelViewProjectionSpace*particleVert;
    
    vertexOut.position=position;
    vertexOut.transperancy=transperancy;
    
    return vertexOut;
}

fragment float4 fragmentParticleShader(VertexOutput vertexOut [[stage_in]], constant UniformParticleProperty &uniformParticleProperty [[buffer (1)]], texture2d<float> texture[[texture(0)]], sampler sam [[sampler(0)]]){
    
    float4 finalColor;
    
    if(uniformParticleProperty.hasTexture){
        
    }else{
        
        finalColor=uniformParticleProperty.diffuseColor;
        
    }
    
    finalColor*=vertexOut.transperancy;
    
    return finalColor;
    
}

