//
//  U4DOffscreenPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DOffscreenPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DShaderProtocols.h"

namespace U4DEngine{

    U4DOffscreenPipeline::U4DOffscreenPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DModelPipeline(uMTLDevice, uName){
       
    }

    U4DOffscreenPipeline::~U4DOffscreenPipeline(){
        
    }

    void U4DOffscreenPipeline::initRenderPassTargetTexture(){
        
        //create texture descriptor
        MTLTextureDescriptor *offscreenRenderTextureDescriptor = [MTLTextureDescriptor new];
        
        offscreenRenderTextureDescriptor.textureType = MTLTextureType2D;
        offscreenRenderTextureDescriptor.width = 1024.0;
        offscreenRenderTextureDescriptor.height = 1024.0;
        offscreenRenderTextureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
        offscreenRenderTextureDescriptor.usage = MTLTextureUsageRenderTarget |
                              MTLTextureUsageShaderRead;
        
        //create first pass texture
        
        targetTexture=[mtlDevice newTextureWithDescriptor:offscreenRenderTextureDescriptor];
        
        
        //create depth texture
        MTLTextureDescriptor *offscreenDepthTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1024 height:1024 mipmapped:NO];
        
        offscreenDepthTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
        offscreenDepthTextureDescriptor.storageMode=MTLStorageModePrivate;
        
        targetDepthTexture=[mtlDevice newTextureWithDescriptor:offscreenDepthTextureDescriptor];
        
    }

    void U4DOffscreenPipeline::initRenderPassDesc(){
        
        //set up the offscreen render pass descriptor
        
        mtlRenderPassDescriptor=[MTLRenderPassDescriptor new];
        mtlRenderPassDescriptor.colorAttachments[0].texture=targetTexture;
        mtlRenderPassDescriptor.depthAttachment.texture=targetDepthTexture;
        
        mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        mtlRenderPassDescriptor.depthAttachment.loadAction=MTLLoadActionClear;
        mtlRenderPassDescriptor.depthAttachment.clearDepth=1.0;
        mtlRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
    }

    void U4DOffscreenPipeline::initRenderPassPipeline(){
        
        NSError *error;

        mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=MTLPixelFormatRGBA8Unorm;
        mtlRenderPassPipelineDescriptor.depthAttachmentPixelFormat=MTLPixelFormatDepth32Float;

        mtlRenderPassPipelineDescriptor.vertexDescriptor=vertexDesc;

        mtlRenderPassDepthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
        mtlRenderPassDepthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;
        
        mtlRenderPassDepthStencilDescriptor.depthWriteEnabled=YES;
        
        //create depth stencil state
        mtlRenderPassDepthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:mtlRenderPassDepthStencilDescriptor];
        
        
        //create the rendering pipeline object
        mtlRenderPassPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPassPipelineDescriptor error:&error];
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!mtlRenderPassPipelineState){
            
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            logger->log("Error: The pipeline %s was unable to be created. %s",name.c_str(),errorDesc.c_str());
            
        }else{
            
            logger->log("Success: The pipeline %s was properly configured",name.c_str());
        }
        
    }

    void U4DOffscreenPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        if(mtlRenderPassDescriptor!=nil){
            
            
                        
            [uRenderEncoder setViewport:(MTLViewport){0.0, 0.0, 1024.0, 1024.0, 0.0, 1.0 }];
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

            [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
            
            //bind resources
            
            uEntity->render(uRenderEncoder);
            
        }
    }

}
