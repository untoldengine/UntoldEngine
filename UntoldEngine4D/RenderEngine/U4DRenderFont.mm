//
//  U4DRenderFont.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DRenderFont.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DRenderFont::U4DRenderFont(U4DImage *uU4DImage):U4DEngine::U4DRenderImage(uU4DImage){
        
        u4dObject=uU4DImage;
    }
    
    U4DRenderFont::~U4DRenderFont(){
        
    }
    
    void U4DRenderFont::updateRenderingInformation(){
        
        alignedAttributeData();
        
        memcpy(attributeBuffer.contents, (void*)&attributeAlignedContainer[0], sizeof(AttributeAlignedImageData)*attributeAlignedContainer.size());
        
        memcpy(indicesBuffer.contents, (void*)&u4dObject->bodyCoordinates.indexContainer[0], sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size());
        
        clearModelAttributeData();
        
    }
    
    void U4DRenderFont::modifyRenderingInformation(){
        
        alignedAttributeData();
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedImageData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        clearModelAttributeData();
        
    }
    
    void U4DRenderFont::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            //diffuse texture
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
        
            
        }
        
    }
    
    
    void U4DRenderFont::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
        u4dObject->bodyCoordinates.indexContainer.clear();
    }
    
}
