//
//  U4DModelPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DModelPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DSceneManager.h"
#include "U4DShaderProtocols.h"

namespace U4DEngine{

    U4DModelPipeline::U4DModelPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
        
    }

    U4DModelPipeline::~U4DModelPipeline(){
        
    }

    void U4DModelPipeline::initRenderPassTargetTexture(){
        
        //the target for this is the default framebuffer
    }

    void U4DModelPipeline::initVertexDesc(){
        
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

    void U4DModelPipeline::initRenderPassDesc(){
    
        U4DDirector *director=U4DDirector::sharedInstance();
        
        mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
        mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
        mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        
    }

    void U4DModelPipeline::initRenderPassPipeline(){
        
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

    void U4DModelPipeline::initRenderPassAdditionalInfo(){
    
        
        U4DDirector *director=U4DDirector::sharedInstance();

        UniformShadowProperties shadowProperties;

        shadowProperties.biasDepth=director->getShadowBiasDepth();
        
        shadowPropertiesUniform=[mtlDevice newBufferWithBytes:&shadowProperties length:sizeof(UniformShadowProperties) options:MTLResourceStorageModeShared];
        

//
//        memcpy(shadowPropertiesBuffer.contents, (void*)&shadowProperties, sizeof(UniformModelShadowProperties));
    }

    void U4DModelPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){
        
        
        //encode the pipeline
        [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

        [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
        
        
        //inpute texture here is the depth texture for the shadow
        [uRenderEncoder setFragmentTexture:inputTexture atIndex:fiDepthTexture];
        
        [uRenderEncoder setFragmentBuffer:shadowPropertiesUniform offset:0 atIndex:fiShadowPropertiesBuffer];
        
        
        //bind resources
        
        uEntity->render(uRenderEncoder);
        
    }

}
