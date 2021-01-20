//
//  U4DGeometryPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DGeometryPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DGeometryPipeline::U4DGeometryPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
    }
        
    U4DGeometryPipeline::~U4DGeometryPipeline(){
        
    }
        
    void U4DGeometryPipeline::initRenderPassTargetTexture(){
        
    }
        
    void U4DGeometryPipeline::initVertexDesc(){
        
        //set the vertex descriptors

        vertexDesc=[[MTLVertexDescriptor alloc] init];

        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;

        //stride
        vertexDesc.layouts[0].stride=4*sizeof(float);

        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
    }

    void U4DGeometryPipeline::initRenderPassDesc(){
        
    }
        
    void U4DGeometryPipeline::initRenderPassPipeline(){
        
        NSError *error;
        U4DDirector *director=U4DDirector::sharedInstance();

        mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPassPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;

        mtlRenderPassPipelineDescriptor.vertexDescriptor=vertexDesc;
        
        mtlRenderPassDepthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];

        mtlRenderPassDepthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;

        mtlRenderPassDepthStencilDescriptor.depthWriteEnabled=YES;

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
        
    void U4DGeometryPipeline::initRenderPassAdditionalInfo(){
        
    }
        
    void U4DGeometryPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
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
