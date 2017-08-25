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
    
    U4DRenderSprite::U4DRenderSprite(U4DImage *uU4DImage):U4DEngine::U4DRenderImage(uU4DImage),spriteOffset(0.0,0.0){
        
        u4dObject=uU4DImage;
        
    }
    
    U4DRenderSprite::~U4DRenderSprite(){
        
    }
    
    void U4DRenderSprite::loadMTLAdditionalInformation(){
        
        //create the uniform
        uniformSpriteBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpriteProperty) options:MTLResourceStorageModeShared];
        
    }
    
    void U4DRenderSprite::setSpriteOffset(U4DVector2n &uSpriteOffset){
        
        spriteOffset=uSpriteOffset;
        
    }
    
    void U4DRenderSprite::updateSpriteBufferUniform(){
        
        vector_float2 spriteOffsetSIMD=convertToSIMD(spriteOffset);
        
        UniformSpriteProperty spriteProperty;
        spriteProperty.offset=spriteOffsetSIMD;
        
        memcpy(uniformSpriteBuffer.contents, (void*)&spriteProperty, sizeof(UniformSpriteProperty));
    }
    
    void U4DRenderSprite::setSpriteDimension(float uSpriteWidth,float uSpriteHeight, float uAtlasWidth,float uAtlasHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        float widthFontTexture=uSpriteWidth/uAtlasWidth;
        float heightFontTexture=uSpriteHeight/uAtlasHeight;
        
        float width=uSpriteWidth/director->getDisplayWidth();
        float height=uSpriteHeight/director->getDisplayHeight();
        float depth=0.0;
        
        
        //vertices
        U4DVector3n v1(width,height,depth);
        U4DVector3n v4(width,-height,depth);
        U4DVector3n v2(-width,-height,depth);
        U4DVector3n v3(-width,height,depth);
        
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v1);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v4);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v2);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v3);
        
        //texture
        U4DVector2n t4(0.0,0.0);  //top left
        U4DVector2n t1(1.0*widthFontTexture,0.0);  //top right
        U4DVector2n t3(0.0,1.0*heightFontTexture);  //bottom left
        U4DVector2n t2(1.0*widthFontTexture,1.0*heightFontTexture);  //bottom right
        
        
        u4dObject->bodyCoordinates.addUVDataToContainer(t1);
        u4dObject->bodyCoordinates.addUVDataToContainer(t2);
        u4dObject->bodyCoordinates.addUVDataToContainer(t3);
        u4dObject->bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        
        //index
        u4dObject->bodyCoordinates.addIndexDataToContainer(i1);
        u4dObject->bodyCoordinates.addIndexDataToContainer(i2);
        
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
