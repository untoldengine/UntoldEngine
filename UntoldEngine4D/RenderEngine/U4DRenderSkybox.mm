//
//  U4DRenderSkybox.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/12/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderSkybox.h"

#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"
#include "U4DLogger.h"
#include "U4DResourceLoader.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DRenderSkybox::U4DRenderSkybox(U4DSkybox *uU4DSkybox):textureObject{nil},samplerStateObject{nil},samplerDescriptor{nullptr}{
        
        u4dObject=uU4DSkybox;
    }
    
    U4DRenderSkybox::~U4DRenderSkybox(){
        
        [textureObject setPurgeableState:MTLPurgeableStateEmpty];
        [textureObject release];
        
        [samplerStateObject release];
        [samplerDescriptor release];
         
        textureObject=nil;
        samplerStateObject=nil;
        samplerDescriptor=nil;
        
    }
    
    
    bool U4DRenderSkybox::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedSkyboxData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderSkybox::loadMTLTexture(){
        
        //Create the texture descriptor
        
        if (!u4dObject->textureInformation.texture0.empty()){
            
            createTextureObject(textureObject);
            
            createSamplerObject(samplerStateObject,samplerDescriptor);
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            logger->log("ERROR: The skybox requires 6 textures");
        }
        
        clearRawImageData();
        
    }
    
    void U4DRenderSkybox::createTextureObject(id<MTLTexture> &uTexture){ 
        
        int skyboxTextureSize = 0;
        
        std::vector<std::string> tempSkyboxTexture{u4dObject->textureInformation.texture0,u4dObject->textureInformation.texture1,u4dObject->textureInformation.texture2,u4dObject->textureInformation.texture3,u4dObject->textureInformation.texture4,u4dObject->textureInformation.texture5};
        
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        for(int t=0;t<resourceLoader->texturesContainer.size();t++){

            if (resourceLoader->texturesContainer.at(t).name.compare(u4dObject->textureInformation.texture0)==0) {
                
                skyboxTextureSize=resourceLoader->texturesContainer.at(t).width;
                
            }

        }
        
        
        //once we have the total size of the texture, then proceed with creating the texture object.
        
        MTLTextureDescriptor *textureDescriptor=[MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm size:skyboxTextureSize mipmapped:NO];
        
        //Create the texture object
        textureObject=[mtlDevice newTextureWithDescriptor:textureDescriptor];
        
        std::vector<unsigned char> skyboxImage;
        
        for (int slice=0; slice<6; slice++) {
            
            
            for(int t=0;t<resourceLoader->texturesContainer.size();t++){

                if (resourceLoader->texturesContainer.at(t).name.compare(tempSkyboxTexture.at(slice))==0) {
                    
                    setRawImageData(resourceLoader->texturesContainer.at(t).image);
                    
                    imageWidth=resourceLoader->texturesContainer.at(t).width;
                    imageHeight=resourceLoader->texturesContainer.at(t).height;
                    
                    MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
                    [textureObject replaceRegion:region mipmapLevel:0 slice:slice withBytes:&rawImageData[0] bytesPerRow:4*imageWidth bytesPerImage:4*imageWidth*imageHeight];
        
                    clearRawImageData();
                    
                    break;
                    
                }

            }
            
        }

    }
    
    
    void U4DRenderSkybox::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=u4dObject->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n worldSpace(1,0,0,0,
                               0,1,0,0,
                               0,0,1,0,
                               0,0,0,1);
        
        //YOU NEED TO MODIFY THIS SO THAT IT USES THE U4DCAMERA Position
        U4DEngine::U4DMatrix4n viewSpace=camera->getLocalSpace().transformDualQuaternionToMatrix4n();
        viewSpace.invert();
        
        U4DMatrix4n modelWorldSpace=worldSpace*modelSpace;
        
        U4DMatrix4n modelWorldViewSpace=viewSpace*modelWorldSpace;
        
        U4DMatrix4n perspectiveProjection=director->getPerspectiveSpace();
        
        U4DMatrix4n mvpSpace=perspectiveProjection*modelWorldViewSpace;
        
        U4DNumerical numerical;
        matrix_float4x4 mvpSpaceSIMD=numerical.convertToSIMD(mvpSpace);
        
        
        UniformSpace uniformSpace;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderSkybox::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:viSpaceBuffer];
            
            [uRenderEncoder setFragmentTexture:textureObject atIndex:fiTexture0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:fiSampler0];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }
    
    void U4DRenderSkybox::alignedAttributeData(){
        
        //create the structure that contains the align data
        AttributeAlignedSkyboxData attributeAlignedData;
        
        U4DNumerical numerical;
        
        //initialize the container to a temp container
        std::vector<AttributeAlignedSkyboxData> attributeAlignedContainerTemp(u4dObject->bodyCoordinates.getVerticesDataFromContainer().size(),attributeAlignedData);
        
        //copy the temp containter to the actual container. I wanted to initialize the container directly without using the temp container
        //but it kept giving me errors. I think there is a better way to do this.
        attributeAlignedContainer=attributeAlignedContainerTemp;
        
        
        for(int i=0;i<attributeAlignedContainer.size();i++){
            
            U4DVector3n vertexData=u4dObject->bodyCoordinates.verticesContainer.at(i);
            attributeAlignedContainer.at(i).position.xyz=numerical.convertToSIMD(vertexData);
            attributeAlignedContainer.at(i).position.w=1.0;
            
        }
        
    }
    
    void U4DRenderSkybox::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        
    }
    
    
}
