//
//  U4DRenderPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/28/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderPipeline.h"
#include "U4DShaderProtocols.h"
#include "U4DDirector.h"
#include "U4DNumerical.h"
#include "U4DSceneManager.h"
#include "U4DLights.h"


namespace U4DEngine {

    U4DRenderPipeline::U4DRenderPipeline(id <MTLDevice> uMTLDevice, std::string uName):mtlDevice(uMTLDevice),name(uName){
        
    }
        
    U4DRenderPipeline::~U4DRenderPipeline(){
        
    }

    void U4DRenderPipeline::initRenderPass(std::string uVertexShader, std::string uFragmentShader){
        
        initRenderPassTargetTexture();
        initVertexDesc();
        initRenderPassLibrary(uVertexShader,uFragmentShader);
        initRenderPassDesc();
        initRenderPassPipeline();
        initRenderPassAdditionalInfo();
        
        
    }

    std::string U4DRenderPipeline::getName(){
        
        return name;
        
    }

    void U4DRenderPipeline::initRenderPassLibrary(std::string uVertexShader, std::string uFragmentShader){
        
        //init the library
        mtlLibrary=[mtlDevice newDefaultLibrary];

        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uVertexShader.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uFragmentShader.c_str()]];
        
    }

    void U4DRenderPipeline::initRenderPassAdditionalInfo(){
        
        
        
    }

    id<MTLTexture> U4DRenderPipeline::getTargetTexture(){
        
        return targetTexture;
        
    }

    void U4DRenderPipeline::setInputTexture(id<MTLTexture> uInputTexture){
        inputTexture=uInputTexture;
    }

//    void U4DRenderPipeline::bindResources(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uRootEntity, int uRenderPass){
//
////        for(const auto &n:renderPassEntityContainer){
////
////            n->render(uRenderEncoder);
////
////        }
//
//        U4DEntity *child=uRootEntity;
//
//        while (child!=NULL) {
//
//            if((child->getRenderPassFilter()&uRenderPass)==uRenderPass){
//
//                child->render(uRenderEncoder);
//
//            }
//
//               child=child->next;
//
//           }
//
//    }

    void U4DRenderPipeline::createTextureObject(id<MTLTexture> &uTextureObject){
        
    }

    void U4DRenderPipeline::createSamplerObject(id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor){
        
    }

    void U4DRenderPipeline::initTextureSamplerObjectNull(){
        
    }

    bool U4DRenderPipeline::createTextureAndSamplerObjects(id<MTLTexture> &uTextureObject, id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor, std::string uTextureName){
        
    }

    void U4DRenderPipeline::hotReloadShaders(std::string uFilepath){
        
    }

}
