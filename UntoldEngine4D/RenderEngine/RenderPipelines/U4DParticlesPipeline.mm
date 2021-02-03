//
//  U4DParticlesPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DParticlesPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"

namespace U4DEngine{

    U4DParticlesPipeline::U4DParticlesPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
    }

    U4DParticlesPipeline::~U4DParticlesPipeline(){
        
    }

    void U4DParticlesPipeline::initRenderPassTargetTexture(){
        
    }

    void U4DParticlesPipeline::initVertexDesc(){
        
        //set the vertex descriptors

        vertexDesc=[[MTLVertexDescriptor alloc] init];

        //position data
        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;

        //uv data
        vertexDesc.attributes[1].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[1].bufferIndex=0;
        vertexDesc.attributes[1].offset=4*sizeof(float);

        //stride with padding
        vertexDesc.layouts[0].stride=8*sizeof(float);

        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
    }

    void U4DParticlesPipeline::initRenderPassDesc(){
        
    }

    void U4DParticlesPipeline::initRenderPassPipeline(){

        NSError *error;
        
        U4DDirector *director=U4DDirector::sharedInstance();

        mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPassPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;

        mtlRenderPassPipelineDescriptor.colorAttachments[0].blendingEnabled=YES;

        //rgb blending
        mtlRenderPassPipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;

//        if (u4dObject->getEnableAdditiveRendering()) {
//
            mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOne;

//        }else{

//            mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;

//        }

        //alpha blending
        mtlRenderPassPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorOne;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
        ////alpha blending
        //mtlRenderPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
        //        mtlRenderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=(MTLBlendFactor)u4dObject->getBlendingFactorSource();
        //        mtlRenderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=(MTLBlendFactor)u4dObject->getBlendingFactorDest();
        
        
        mtlRenderPassPipelineDescriptor.vertexDescriptor=vertexDesc;
        

        mtlRenderPassDepthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];

        mtlRenderPassDepthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;

        mtlRenderPassDepthStencilDescriptor.depthWriteEnabled=NO;

        //create depth stencil state
        mtlRenderPassDepthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:mtlRenderPassDepthStencilDescriptor];


        mtlRenderPassPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPassPipelineDescriptor error:&error];
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        if(!mtlRenderPassPipelineState){
            
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            logger->log("Error: The pipeline %s was unable to be created. %s",name.c_str(),errorDesc.c_str());
            
        }else{
            
            logger->log("Success: The pipeline %s was properly configured",name.c_str());
        }

    }

    void U4DParticlesPipeline::initRenderPassAdditionalInfo(){
        
    }

    void U4DParticlesPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
        //encode the pipeline
        [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

        [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
        
        //bind resources
        
        uEntity->render(uRenderEncoder);
    }

}
