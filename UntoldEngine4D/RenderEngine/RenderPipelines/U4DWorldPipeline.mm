//
//  U4DWorldPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DWorldPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DWorldPipeline::U4DWorldPipeline(std::string uName):U4DRenderPipeline(uName){
        
    }

    U4DWorldPipeline::~U4DWorldPipeline(){
        
    }

    void U4DWorldPipeline::initTargetTexture(){
        
    }

    void U4DWorldPipeline::initVertexDesc(){
        
        //set the vertex descriptors

        vertexDesc=[[MTLVertexDescriptor alloc] init];

        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;

        //stride
        vertexDesc.layouts[0].stride=4*sizeof(float);

        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
    }

    void U4DWorldPipeline::initPassDesc(){
        
    }

    bool U4DWorldPipeline::buildPipeline(){
        
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

        mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOne;

        //alpha blending
        mtlRenderPassPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;

        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;

        mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;


        mtlRenderPassPipelineDescriptor.vertexDescriptor=vertexDesc;

        mtlRenderPassDepthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];

        mtlRenderPassDepthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;

        mtlRenderPassDepthStencilDescriptor.depthWriteEnabled=NO;

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

    void U4DWorldPipeline::initAdditionalInfo(){
        
    }

    void U4DWorldPipeline::executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
        //encode the pipeline
        [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

        [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
        
        //bind resources
        
        uEntity->render(uRenderEncoder);
        
    }

}
