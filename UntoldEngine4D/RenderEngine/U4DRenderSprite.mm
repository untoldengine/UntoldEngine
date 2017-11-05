//
//  U4DRenderSprite.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DRenderSprite.h"
#include "U4DShaderProtocols.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DRenderSprite::U4DRenderSprite(U4DImage *uU4DImage):U4DEngine::U4DRenderImage(uU4DImage){
        
        u4dObject=uU4DImage;
        
    }
    
    U4DRenderSprite::~U4DRenderSprite(){
        
    }
    
    void U4DRenderSprite::loadMTLAdditionalInformation(){
        
        //create the uniform
        uniformSpriteBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpriteProperty) options:MTLResourceStorageModeShared];
        
    }
    
    void U4DRenderSprite::updateSpriteBufferUniform(){
        
        vector_float2 spriteOffsetSIMD=convertToSIMD(u4dObject->getSpriteOffset());
        
        UniformSpriteProperty spriteProperty;
        spriteProperty.offset=spriteOffsetSIMD;
        
        memcpy(uniformSpriteBuffer.contents, (void*)&spriteProperty, sizeof(UniformSpriteProperty));
    }
    
    void U4DRenderSprite::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            updateSpriteBufferUniform();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            [uRenderEncoder setVertexBuffer:uniformSpriteBuffer offset:0 atIndex:2];
            
            //diffuse texture
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
            
        }
        
    }
    
}
