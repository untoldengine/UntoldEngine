//
//  U4DRenderMultiImage.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/12/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include "U4DRenderMultiImage.h"

#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DRenderMultiImage::U4DRenderMultiImage(U4DImage *uU4DImage):U4DEngine::U4DRenderImage(uU4DImage),uniformMultiImageBuffer(nil){
        
        u4dObject=uU4DImage;
    }
    
    U4DRenderMultiImage::~U4DRenderMultiImage(){
        
        uniformMultiImageBuffer=nil;
    }
    
    void U4DRenderMultiImage::loadMTLTexture(){
        
        if (!u4dObject->textureInformation.diffuseTexture.empty()){
            
            decodeImage(u4dObject->textureInformation.diffuseTexture);
            
            createTextureObject();
            
            createSamplerObject();
            
            clearRawImageData();
        }
        
        
        
        if (!u4dObject->textureInformation.ambientTexture.empty()) {
            
            decodeImage(u4dObject->textureInformation.ambientTexture);
            
            createSecondaryTextureObject();
            
            clearRawImageData();
        }
        
        
        
    }
    

    
    void U4DRenderMultiImage::loadMTLAdditionalInformation(){
        
        //create the uniform
        uniformMultiImageBuffer=[mtlDevice newBufferWithLength:sizeof(UniformMultiImageState) options:MTLResourceStorageModeShared];
        
    }
    
    void U4DRenderMultiImage::createSecondaryTextureObject(){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *textureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the texture object
        secondaryTextureObject=[mtlDevice newTextureWithDescriptor:textureDescriptor];
        
        //Copy the raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [secondaryTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
    
        
    }
    
    
    void U4DRenderMultiImage::setDiffuseTexture(const char* uTexture){
        
        u4dObject->textureInformation.diffuseTexture=uTexture;
        
    }
    
    void U4DRenderMultiImage::setAmbientTexture(const char* uTexture){
        
        u4dObject->textureInformation.ambientTexture=uTexture;
        
    }
    
    
    void U4DRenderMultiImage::updateMultiImage(){
        
        UniformMultiImageState uniformMultiImageState;
        
        uniformMultiImageState.changeImage=u4dObject->getImageState();
        
        memcpy(uniformMultiImageBuffer.contents, (void*)&uniformMultiImageState, sizeof(UniformMultiImageState));
    }
    
    void U4DRenderMultiImage::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            updateMultiImage();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            //diffuse texture
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            //ambient texture
            [uRenderEncoder setFragmentTexture:secondaryTextureObject atIndex:1];
            
            //image state
            [uRenderEncoder setFragmentBuffer:uniformMultiImageBuffer offset:0 atIndex:1];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }
    
}
