//
//  U4DShadowRenderPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DShadowRenderPipeline.h"
#include "U4DRenderEntity.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DShaderProtocols.h"
#include "U4DNumerical.h"
#include "U4DLogger.h"

namespace U4DEngine {

U4DShadowRenderPipeline::U4DShadowRenderPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
        
    }

    U4DShadowRenderPipeline::~U4DShadowRenderPipeline(){
        
    }

    void U4DShadowRenderPipeline::initRenderPassTargetTexture(){
        
        MTLTextureDescriptor *shadowTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1024 height:1024 mipmapped:NO];
        
        shadowTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
        shadowTextureDescriptor.storageMode=MTLStorageModePrivate;
        
        targetTexture=[mtlDevice newTextureWithDescriptor:shadowTextureDescriptor];
        
    }

    void U4DShadowRenderPipeline::initRenderPassLibrary(std::string uVertexShader, std::string uFragmentShader){
        
        //init the library
        mtlLibrary=[mtlDevice newDefaultLibrary];

        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:uVertexShader.c_str()]];
        fragmentProgram=nil;
        
    }

    void U4DShadowRenderPipeline::initVertexDesc(){
        
        //set the vertex descriptors

        vertexDesc=[[MTLVertexDescriptor alloc] init];

        //position data
        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;
        
        //normal data
        vertexDesc.attributes[1].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[1].bufferIndex=0;
        vertexDesc.attributes[1].offset=4*sizeof(float);
        
        //uv data
        vertexDesc.attributes[2].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[2].bufferIndex=0;
        vertexDesc.attributes[2].offset=8*sizeof(float);
        
        //tangent data
        vertexDesc.attributes[3].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[3].bufferIndex=0;
        vertexDesc.attributes[3].offset=12*sizeof(float);
        
        //Material data
        vertexDesc.attributes[4].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[4].bufferIndex=0;
        vertexDesc.attributes[4].offset=16*sizeof(float);
        
        //vertex weight
        vertexDesc.attributes[5].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[5].bufferIndex=0;
        vertexDesc.attributes[5].offset=20*sizeof(float);
        
        //bone index
        vertexDesc.attributes[6].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[6].bufferIndex=0;
        vertexDesc.attributes[6].offset=24*sizeof(float);
        
        //stride with padding
        vertexDesc.layouts[0].stride=28*sizeof(float);
        
        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;

    }

    void U4DShadowRenderPipeline::initRenderPassDesc(){
        
        //create a shadow pass descriptor
        mtlRenderPassDescriptor=[MTLRenderPassDescriptor new];
        
        mtlRenderPassDepthAttachmentDescriptor=mtlRenderPassDescriptor.depthAttachment;
        
        //Set the texture on the render pass descriptor
        mtlRenderPassDepthAttachmentDescriptor.texture=targetTexture;
        
        //Set other properties on the render pass descriptor
        mtlRenderPassDepthAttachmentDescriptor.clearDepth=0.0;
        mtlRenderPassDepthAttachmentDescriptor.loadAction=MTLLoadActionClear;
        mtlRenderPassDepthAttachmentDescriptor.storeAction=MTLStoreActionStore;
        
    }

    void U4DShadowRenderPipeline::initRenderPassPipeline(){
        
        //set the pipeline descriptor
        NSError *error;
        
         mtlRenderPassPipelineDescriptor=[MTLRenderPipelineDescriptor new];
         mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
         mtlRenderPassPipelineDescriptor.fragmentFunction=nil;
         mtlRenderPassPipelineDescriptor.depthAttachmentPixelFormat=targetTexture.pixelFormat;
        
         mtlRenderPassPipelineDescriptor.vertexDescriptor=vertexDesc;

         
         //Set the depth stencil descriptors
         mtlRenderPassDepthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
         mtlRenderPassDepthStencilDescriptor.depthCompareFunction=MTLCompareFunctionGreater;
         mtlRenderPassDepthStencilDescriptor.depthWriteEnabled=YES;
         
         //add stencil description
         mtlRenderPassStencilStateDescriptor=[[MTLStencilDescriptor alloc] init];
         mtlRenderPassStencilStateDescriptor.stencilCompareFunction=MTLCompareFunctionAlways;
         mtlRenderPassStencilStateDescriptor.stencilFailureOperation=MTLStencilOperationKeep;

         mtlRenderPassDepthStencilDescriptor.frontFaceStencil=mtlRenderPassStencilStateDescriptor;
         mtlRenderPassDepthStencilDescriptor.backFaceStencil=mtlRenderPassStencilStateDescriptor;

         mtlRenderPassDepthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:mtlRenderPassDepthStencilDescriptor];
         
         //create the render pipeline
         mtlRenderPassPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPassPipelineDescriptor error:&error];
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!mtlRenderPassPipelineState){
            
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            logger->log("Error: The pipeline %s was unable to be created. %s",name.c_str(),errorDesc.c_str());
            
        }else{
            
            logger->log("Success: The pipeline %s was properly configured",name.c_str());
        }
        
    }

    void U4DShadowRenderPipeline::initRenderPassAdditionalInfo(){

        
        
    }

    void U4DShadowRenderPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
        
        //set the states
        [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];
        [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
        
        
        //bind resources
        
        uEntity->render(uRenderEncoder);
        
    }

}
