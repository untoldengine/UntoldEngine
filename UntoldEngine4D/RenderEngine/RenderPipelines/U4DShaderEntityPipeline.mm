//
//  U4DShaderEntityPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/13/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DShaderEntityPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"

namespace U4DEngine{

    U4DShaderEntityPipeline::U4DShaderEntityPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
    }

    U4DShaderEntityPipeline::~U4DShaderEntityPipeline(){
        
    }

    void U4DShaderEntityPipeline::initRenderPassTargetTexture(){
        
    }

    void U4DShaderEntityPipeline::initVertexDesc(){
        
        //set the vertex descriptors

        vertexDesc=[[MTLVertexDescriptor alloc] init];

        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;

        vertexDesc.attributes[1].format=MTLVertexFormatFloat2;
        vertexDesc.attributes[1].bufferIndex=0;
        vertexDesc.attributes[1].offset=4*sizeof(float);

        //stride is 10 but must provide padding so it makes it 12
        vertexDesc.layouts[0].stride=8*sizeof(float);

        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
    }

    void U4DShaderEntityPipeline::initRenderPassDesc(){
        
    }

    void U4DShaderEntityPipeline::initRenderPassPipeline(){

        NSError *error;
        
        U4DDirector *director=U4DDirector::sharedInstance();

        mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;

        //if(u4dObject->getEnableBlending()){
            mtlRenderPassPipelineDescriptor.colorAttachments[0].blendingEnabled=YES;
        //}else{
            //mtlRenderPassPipelineDescriptor.colorAttachments[0].blendingEnabled=NO;
        //}

        //rgb blending
        mtlRenderPassPipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;

        //original blend factor
        //mtlRenderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceColor;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;

        //if (u4dObject->getEnableAdditiveRendering()) {

            mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOne;

        //}else{

            //mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;

        //}

        //alpha blending
        mtlRenderPassPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;

        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;

        mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;


        mtlRenderPassPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;

    
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
            logger->log("Error: The pipeline was unable to be created. %s",errorDesc.c_str());
            
        }else{
            
            logger->log("Success: The pipeline was properly configured");
        }

    }

    void U4DShaderEntityPipeline::initRenderPassAdditionalInfo(){
        
    }

    void U4DShaderEntityPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
        U4DDirector *director=U4DDirector::sharedInstance();
            
        float screenContentScale=director->getScreenScaleFactor();
        
        [uRenderEncoder setViewport:(MTLViewport){0.0, 0.0, director->getMTLView().bounds.size.width*screenContentScale, director->getMTLView().bounds.size.height*screenContentScale, 0.0, 1.0 }];
        
        //encode the pipeline
        [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

        [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
        
        //bind resources
        
        uEntity->render(uRenderEncoder);
    }

}
