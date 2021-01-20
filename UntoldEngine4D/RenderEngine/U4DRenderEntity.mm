//
//  U4DRenderEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/28/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderEntity.h"
#include "U4DDirector.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DShaderProtocols.h"
#include <simd/simd.h>
#include "U4DLogger.h"
#include "U4DResourceLoader.h"
#include "U4DNumerical.h"
#include "U4DRenderManager.h"

namespace U4DEngine {

U4DRenderEntity::U4DRenderEntity():eligibleToRender(false),isWithinFrustum(false),mtlDevice(nil),attributeBuffer(nil),indicesBuffer(nil),uniformSpaceBuffer(nil){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        mtlDevice=director->getMTLDevice();
        
    }
    
    U4DRenderEntity::~U4DRenderEntity(){

        [attributeBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [indicesBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [uniformSpaceBuffer setPurgeableState:MTLPurgeableStateEmpty];
        
        
        [attributeBuffer release];
        [indicesBuffer release];
        [uniformSpaceBuffer release];
        
        
        attributeBuffer=nil;
        indicesBuffer=nil;
        uniformSpaceBuffer=nil;
        
        
    }
    
    void U4DRenderEntity::loadRenderingInformation(){
        
        if(loadMTLBuffer()){
            
            loadMTLTexture();
            
            //loads additional information such as normal map, bones, etc if it exists.
            loadMTLAdditionalInformation();
            
            //clear all model attribute data
            clearModelAttributeData();
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No rendering data was found for the object. This object will not be rendered by the engine");
            
        }
        
    }

    void U4DRenderEntity::makePassPipelinePair(int uRenderPassKey, std::string uPipelineName){
        
        U4DRenderPipelineInterface *pipeline=nullptr;
        
        U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
        
        pipeline=renderManager->searchPipeline(uPipelineName);
        
        if (pipeline!=nullptr) {
            renderPassPipelineMap.insert(std::make_pair(uRenderPassKey, pipeline));
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("The pair for pipeline %s was not successful. The pipeline was not found", uPipelineName.c_str());
            
        }
        
        
    }

    void U4DRenderEntity::removePassPipelinePair(int uRenderPassKey){
        
        renderPassPipelineMap.erase(uRenderPassKey);
        
    }
        
    U4DRenderPipelineInterface *U4DRenderEntity::getPipeline(int uRenderPassKey){
        
        U4DRenderPipelineInterface *pipeline=nullptr;
        
        if(renderPassPipelineMap.find(uRenderPassKey)==renderPassPipelineMap.end()){
            
            pipeline=nullptr;
            
        }else{
            
            pipeline=renderPassPipelineMap.find(uRenderPassKey)->second;
        }
            
    
        return pipeline;
    }
    
    void U4DRenderEntity::clearRawImageData(){
        
        imageWidth=0;
        imageHeight=0;
        rawImageData.clear();
    }
    
    void U4DRenderEntity::createTextureObject(id<MTLTexture> &uTextureObject){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *textureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the texture object
        uTextureObject=[mtlDevice newTextureWithDescriptor:textureDescriptor];
        
        //Copy the raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [uTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
    }
    
    void U4DRenderEntity::createSamplerObject(id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor){
        
        //Create a sampler descriptor
        
        uSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        //Set the filtering and addressing settings
        uSamplerDescriptor.minFilter=MTLSamplerMinMagFilterLinear;
        uSamplerDescriptor.magFilter=MTLSamplerMinMagFilterLinear;
        
        //set the addressing mode for the S component
        uSamplerDescriptor.sAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //set the addressing mode for the T component
        uSamplerDescriptor.tAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //Create the sampler state object
        
        uSamplerStateObject=[mtlDevice newSamplerStateWithDescriptor:uSamplerDescriptor];
        
    }
    
    

    bool U4DRenderEntity::createTextureAndSamplerObjects(id<MTLTexture> &uTextureObject, id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor, std::string uTextureName){
        
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        if(resourceLoader->loadTextureDataToEntity(this, uTextureName.c_str())){
            
            createTextureObject(uTextureObject);
            
            createSamplerObject(uSamplerStateObject,uSamplerDescriptor);
            
            clearRawImageData();
            
            return true;
        }
        
        return false;
        
    }
    

    void U4DRenderEntity::setIsWithinFrustum(bool uValue){
        
        if(uValue==true){
            
            U4DDirector *director=U4DDirector::sharedInstance();
            
            director->setModelsWithinFrustum(true);
            
        }
        
        isWithinFrustum=uValue;
        
    }
    

    void U4DRenderEntity::setRawImageData(std::vector<unsigned char> uRawImageData){
            
            rawImageData=uRawImageData;
            
        }

    void U4DRenderEntity::setImageWidth(unsigned int uImageWidth){
        
        imageWidth=uImageWidth;
        
    }

    void U4DRenderEntity::setImageHeight(unsigned int uImageHeight){
        
        imageHeight=uImageHeight;
    }

}
