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
#include "U4DShaderHelperFunctions.h"

struct VertexInput {
    
    float4    position [[ attribute(0) ]];
    float2    uv       [[ attribute(1) ]];
    
};

struct VertexOutput{
    
    float4 position [[position]];
    float4 color;
    float2 uvCoords;
    
};

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
            
            sampledColor=sampledColor*valueNoise(vertexOut.uvCoords*uniformParticleSystemProperty.noiseDetail)*vertexOut.color;
            
        }else{
            sampledColor=sampledColor*vertexOut.color;
        }
        
    }else{
        sampledColor=vertexOut.color;
    }
    
    return sampledColor;
    
}


