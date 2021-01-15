//
//  U4DRenderImage.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderImage.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"
#include "U4DNumerical.h"

namespace U4DEngine {

    U4DRenderImage::U4DRenderImage(U4DImage *uU4DImage):textureObject{nil},samplerStateObject{nil},samplerDescriptor{nullptr}{
        
        u4dObject=uU4DImage;
    }
    
    U4DRenderImage::~U4DRenderImage(){
        
        [textureObject setPurgeableState:MTLPurgeableStateEmpty];
        [textureObject release];
       
        [samplerStateObject release];
        [samplerDescriptor release];
        
        textureObject=nil;
        samplerStateObject=nil;
        samplerDescriptor=nil;
        
    }
    
    bool U4DRenderImage::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedImageData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderImage::loadMTLTexture(){
        
        if (!u4dObject->textureInformation.texture0.empty() && rawImageData.size()>0){
            
            createTextureObject(textureObject);
            
            createSamplerObject(samplerStateObject,samplerDescriptor);
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No data found for the Image Texture");
            
        }
        
        clearRawImageData();
        
    }
    
    
    void U4DRenderImage::updateSpaceUniforms(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=u4dObject->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n worldSpace(1,0,0,0,
                               0,1,0,0,
                               0,0,1,0,
                               0,0,0,1);
        
        //YOU NEED TO MODIFY THIS SO THAT IT USES THE U4DCAMERA Position
        U4DEngine::U4DMatrix4n viewSpace;
        
        U4DMatrix4n modelWorldSpace=worldSpace*modelSpace;
        
        U4DMatrix4n modelWorldViewSpace=viewSpace*modelWorldSpace;
        
        U4DMatrix4n orthogonalProjection=director->getOrthographicSpace();
        
        U4DMatrix4n mvpSpace=orthogonalProjection*modelWorldViewSpace;
        
        U4DNumerical numerical;
        
        matrix_float4x4 mvpSpaceSIMD=numerical.convertToSIMD(mvpSpace);
        
        
        UniformSpace uniformSpace;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderImage::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:viSpaceBuffer];
            
            [uRenderEncoder setFragmentTexture:textureObject atIndex:fiTexture0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:fiSampler0];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }
    
    void U4DRenderImage::alignedAttributeData(){
        
        AttributeAlignedImageData attributeAlignedData;
        U4DNumerical numerical;
        
        std::vector<AttributeAlignedImageData> attributeAlignedContainerTemp(u4dObject->bodyCoordinates.getVerticesDataFromContainer().size(),attributeAlignedData);

        attributeAlignedContainer=attributeAlignedContainerTemp;
        
        for(int i=0;i<attributeAlignedContainer.size();i++){
            
            U4DVector3n vertexData=u4dObject->bodyCoordinates.verticesContainer.at(i);
            
            attributeAlignedContainer.at(i).position.xyz=numerical.convertToSIMD(vertexData);
            attributeAlignedContainer.at(i).position.w=1.0;
            
            U4DVector2n uvData=u4dObject->bodyCoordinates.uVContainer.at(i);
            
            attributeAlignedContainer.at(i).uv.xy=numerical.convertToSIMD(uvData);
            
        }
        
    }
    
    void U4DRenderImage::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
    }

    void U4DRenderImage::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null texture sampler object
        nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
    }


}
