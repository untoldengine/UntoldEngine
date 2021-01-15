//
//  U4DImagePipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/5/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DImagePipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DShaderProtocols.h"

namespace U4DEngine{

    U4DImagePipeline::U4DImagePipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
        
    }

    U4DImagePipeline::~U4DImagePipeline(){
        
    }

    void U4DImagePipeline::initRenderPassTargetTexture(){
        
        //the target for this is the default framebuffer
    }

    void U4DImagePipeline::initVertexDesc(){
        
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

    void U4DImagePipeline::initRenderPassDesc(){
    
       U4DDirector *director=U4DDirector::sharedInstance();
       
       mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
       mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
       mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
       mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        
    }

    void U4DImagePipeline::initRenderPassPipeline(){
        
        NSError *error;
        U4DDirector *director=U4DDirector::sharedInstance();

        mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;

        mtlRenderPassPipelineDescriptor.colorAttachments[0].blendingEnabled=YES;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
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

    void U4DImagePipeline::initRenderPassAdditionalInfo(){
    
       
    }

    void U4DImagePipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
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
