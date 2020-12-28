//
//  RenderManager.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 6/30/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderManager.h"
#include "U4DDirector.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DShaderProtocols.h"
#include <simd/simd.h>
#include "U4DLogger.h"
#include "U4DResourceLoader.h"
#include "U4DNumerical.h"

namespace U4DEngine {

U4DRenderManager::U4DRenderManager():eligibleToRender(false),isWithinFrustum(false),mtlDevice(nil),mtlRenderPipelineState(nil),depthStencilState(nil),mtlRenderPipelineDescriptor(nil),mtlLibrary(nil),vertexProgram(nil),fragmentProgram(nil),vertexDesc(nil),depthStencilDescriptor(nil),attributeBuffer(nil),indicesBuffer(nil),uniformSpaceBuffer(nil),globalDataUniform(nil){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        mtlDevice=director->getMTLDevice();
        
    }
    
    U4DRenderManager::~U4DRenderManager(){

        [mtlRenderPipelineDescriptor release];
        [vertexDesc release];
        [depthStencilDescriptor release];
        [mtlRenderPipelineState release];
        [mtlLibrary release];
        
        mtlRenderPipelineDescriptor=nil;
        vertexDesc=nil;
        depthStencilDescriptor=nil;
        mtlLibrary=nil;
        mtlRenderPipelineState=nil;
        depthStencilState=nil;
        vertexProgram=nil;
        fragmentProgram=nil;
        
        [attributeBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [indicesBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [uniformSpaceBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [globalDataUniform setPurgeableState:MTLPurgeableStateEmpty];
        
        [attributeBuffer release];
        [indicesBuffer release];
        [uniformSpaceBuffer release];
        [globalDataUniform release];
        
        attributeBuffer=nil;
        indicesBuffer=nil;
        uniformSpaceBuffer=nil;
        globalDataUniform=nil;
        
    }
    
    void U4DRenderManager::loadRenderingInformation(){
        
        initMTLRenderLibrary();
        initMTLRenderPipeline();
        
        initMTLOffscreenRenderLibrary();
        initMTLOffscreenRenderPipeline();
        
        if(loadMTLBuffer()){
            
            loadMTLTexture();
            
            //loads additional information such as normal map, bones, etc if it exists.
            loadMTLAdditionalInformation();
            
            //load global uniform
            loadMTLGlobalDataUniforms();
            
            //clear all model attribute data
            clearModelAttributeData();
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No rendering data was found for the object. This object will not be rendered by the engine");
            
        }
        
    }
    
    void U4DRenderManager::clearRawImageData(){
        
        imageWidth=0;
        imageHeight=0;
        rawImageData.clear();
    }
    
    void U4DRenderManager::createTextureObject(id<MTLTexture> &uTextureObject){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *textureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the texture object
        uTextureObject=[mtlDevice newTextureWithDescriptor:textureDescriptor];
        
        //Copy the raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [uTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
    }
    
    void U4DRenderManager::createSamplerObject(id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor){
        
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
    
    

    bool U4DRenderManager::createTextureAndSamplerObjects(id<MTLTexture> &uTextureObject, id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor, std::string uTextureName){
        
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        if(resourceLoader->loadTextureDataToEntity(this, uTextureName.c_str())){
            
            createTextureObject(uTextureObject);
            
            createSamplerObject(uSamplerStateObject,uSamplerDescriptor);
            
            clearRawImageData();
            
            return true;
        }
        
        return false;
        
    }
    

    void U4DRenderManager::setIsWithinFrustum(bool uValue){
        
        if(uValue==true){
            
            U4DDirector *director=U4DDirector::sharedInstance();
            
            director->setModelsWithinFrustum(true);
            
        }
        
        isWithinFrustum=uValue;
        
    }
    
    void U4DRenderManager::loadMTLGlobalDataUniforms(){
        
        globalDataUniform=[mtlDevice newBufferWithLength:sizeof(UniformGlobalData) options:MTLResourceStorageModeShared];
        
    }
    
    void U4DRenderManager::updateGlobalDataUniforms(){
        
        U4DNumerical numerical;
        
        U4DDirector *director=U4DDirector::sharedInstance();
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        
        //get the resolution of the display
        U4DVector2n resolution(director->getDisplayWidth(),director->getDisplayHeight());
        
        vector_float2 resolutionSIMD=numerical.convertToSIMD(resolution);
        
        UniformGlobalData uniformGlobalData;
        uniformGlobalData.time=scene->getGlobalTime(); //set the global time
        uniformGlobalData.resolution=resolutionSIMD; //set the display resolution
        
        memcpy(globalDataUniform.contents, (void*)&uniformGlobalData, sizeof(UniformGlobalData));
        
    }

    void U4DRenderManager::setRawImageData(std::vector<unsigned char> uRawImageData){
            
            rawImageData=uRawImageData;
            
        }

    void U4DRenderManager::setImageWidth(unsigned int uImageWidth){
        
        imageWidth=uImageWidth;
        
    }

    void U4DRenderManager::setImageHeight(unsigned int uImageHeight){
        
        imageHeight=uImageHeight;
    }

}

