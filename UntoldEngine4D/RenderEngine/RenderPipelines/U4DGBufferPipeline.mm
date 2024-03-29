//
//  U4DGBufferPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DGBufferPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DShaderProtocols.h"

namespace U4DEngine{

U4DGBufferPipeline::U4DGBufferPipeline(std::string uName):U4DModelPipeline(uName){
    
}

U4DGBufferPipeline::~U4DGBufferPipeline(){
    
}

void U4DGBufferPipeline::initTargetTexture(){
    
    U4DDirector *director=U4DDirector::sharedInstance();
    
    float width=director->getMTLView().drawableSize.width;
    float height=director->getMTLView().drawableSize.height;
    
    MTLTextureDescriptor *albedoTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO];

    albedoTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
    albedoTextureDescriptor.storageMode=MTLStorageModePrivate;
    
//    //create texture descriptor
//    MTLTextureDescriptor *albedoTextureDescriptor = [MTLTextureDescriptor new];
//
//    albedoTextureDescriptor.textureType = MTLTextureType2D;
//    albedoTextureDescriptor.width = 1024.0;
//    albedoTextureDescriptor.height = 1024.0;
//    albedoTextureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
//    albedoTextureDescriptor.usage = MTLTextureUsageRenderTarget |
//                          MTLTextureUsageShaderRead;
    
    albedoTexture=[mtlDevice newTextureWithDescriptor:albedoTextureDescriptor];
    
    MTLTextureDescriptor *normalTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:width height:height mipmapped:NO];
    
    normalTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
    normalTextureDescriptor.storageMode=MTLStorageModePrivate;
    
    normalTexture=[mtlDevice newTextureWithDescriptor:normalTextureDescriptor];
    
    MTLTextureDescriptor *positionTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float width:width height:height mipmapped:NO];
    
    positionTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
    positionTextureDescriptor.storageMode=MTLStorageModePrivate;
    
    positionTexture=[mtlDevice newTextureWithDescriptor:positionTextureDescriptor];
    
    MTLTextureDescriptor *depthTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:width height:height mipmapped:NO];
    
    depthTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
    depthTextureDescriptor.storageMode=MTLStorageModePrivate;
    
    
    depthTexture=[mtlDevice newTextureWithDescriptor:depthTextureDescriptor];
    depthTexture.label=@"depth-texture";
}

void U4DGBufferPipeline::initPassDesc(){
    
    //create a shadow pass descriptor
    mtlRenderPassDescriptor=[MTLRenderPassDescriptor new];
    
    mtlRenderPassDescriptor.colorAttachments[0].texture=albedoTexture;
    mtlRenderPassDescriptor.colorAttachments[1].texture=normalTexture;
    mtlRenderPassDescriptor.colorAttachments[2].texture=positionTexture;
    mtlRenderPassDescriptor.depthAttachment.texture=depthTexture;
    
    mtlRenderPassDepthAttachmentDescriptor=mtlRenderPassDescriptor.depthAttachment;

    //Set the texture on the render pass descriptor
    mtlRenderPassDepthAttachmentDescriptor.texture=depthTexture;

    //Set other properties on the render pass descriptor
    mtlRenderPassDepthAttachmentDescriptor.clearDepth=0.0;
    mtlRenderPassDepthAttachmentDescriptor.loadAction=MTLLoadActionClear;
    mtlRenderPassDepthAttachmentDescriptor.storeAction=MTLStoreActionStore;
    
    mtlRenderPassDescriptor.colorAttachments[0].loadAction=MTLLoadActionClear;
    mtlRenderPassDescriptor.colorAttachments[0].storeAction=MTLStoreActionStore;
    mtlRenderPassDescriptor.colorAttachments[0].clearColor=MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    mtlRenderPassDescriptor.colorAttachments[1].loadAction=MTLLoadActionClear;
    mtlRenderPassDescriptor.colorAttachments[1].storeAction=MTLStoreActionStore;
    mtlRenderPassDescriptor.colorAttachments[1].clearColor=MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    mtlRenderPassDescriptor.colorAttachments[2].loadAction=MTLLoadActionClear;
    mtlRenderPassDescriptor.colorAttachments[2].storeAction=MTLStoreActionStore;
    mtlRenderPassDescriptor.colorAttachments[2].clearColor=MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

    mtlRenderPassDescriptor.depthAttachment.clearDepth=1.0;
    mtlRenderPassDescriptor.depthAttachment.loadAction=MTLLoadActionClear;
    mtlRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
    
    //mtlRenderPassDescriptor.stencilAttachment.texture=depthTexture;
    
}

bool U4DGBufferPipeline::buildPipeline(){
    
    NSError *error;
    
    mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
    mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
    mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
    mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=MTLPixelFormatRGBA8Unorm;
    mtlRenderPassPipelineDescriptor.colorAttachments[1].pixelFormat=MTLPixelFormatRGBA16Float;
    mtlRenderPassPipelineDescriptor.colorAttachments[2].pixelFormat=MTLPixelFormatRGBA16Float;
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
        return true;
    }
    
    return false;
}


void U4DGBufferPipeline::executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
    
    //encode the pipeline
    [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

    [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
    
    [uRenderEncoder setFragmentBuffer:shadowPropertiesUniform offset:0 atIndex:fiShadowPropertiesBuffer];
    
    uEntity->render(uRenderEncoder);
    
}

}
