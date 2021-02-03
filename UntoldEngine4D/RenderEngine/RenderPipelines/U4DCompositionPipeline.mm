//
//  U4DCompositionPipeline.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DCompositionPipeline.h"
#include "U4DDirector.h"
#include "U4DLogger.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"
#include "U4DNumerical.h"

namespace U4DEngine{

    U4DCompositionPipeline::U4DCompositionPipeline(id <MTLDevice> uMTLDevice, std::string uName):U4DRenderPipeline(uMTLDevice, uName){
        
    }

    U4DCompositionPipeline::~U4DCompositionPipeline(){
        
    }

    void U4DCompositionPipeline::initVertexDesc(){
        
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

    void U4DCompositionPipeline::initRenderPassTargetTexture(){
        
    }

    void U4DCompositionPipeline::initRenderPassDesc(){
        
    }

    void U4DCompositionPipeline::initRenderPassPipeline(){
        
        
        quadVerticesBuffer=[mtlDevice newBufferWithBytes:&quadVertices[0] length:sizeof(float)*(sizeof(quadVertices)/sizeof(quadVertices[0])) options:MTLResourceOptionCPUCacheModeDefault];
        
        quadTexCoordsBuffer=[mtlDevice newBufferWithBytes:&quadTexCoords[0] length:sizeof(float)*(sizeof(quadTexCoords)/sizeof(quadTexCoords[0])) options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        
        NSError *error;
        U4DDirector *director=U4DDirector::sharedInstance();

        mtlRenderPassPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
    
        mtlRenderPassPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPassPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;
        
        mtlRenderPassPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPassPipelineDescriptor.fragmentFunction=fragmentProgram;
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
        }
        
    }

    void U4DCompositionPipeline::executePass(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        
        U4DEngine::U4DMatrix4n viewSpace=camera->getLocalSpace().transformDualQuaternionToMatrix4n();
        viewSpace.invert();
        
        U4DNumerical numerical;
        
        matrix_float4x4 viewSpaceSIMD=numerical.convertToSIMD(viewSpace);
        
        UniformSpace uniformSpace;
        uniformSpace.viewSpace=viewSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
        //encode the pipeline
        [uRenderEncoder setRenderPipelineState:mtlRenderPassPipelineState];

        [uRenderEncoder setDepthStencilState:mtlRenderPassDepthStencilState];
        
        
        [uRenderEncoder setVertexBuffer:quadVerticesBuffer offset:0 atIndex:0];
        [uRenderEncoder setVertexBuffer:quadTexCoordsBuffer offset:0 atIndex:1];
        
        [uRenderEncoder setFragmentBuffer:uniformSpaceBuffer offset:0 atIndex:1];
        
        [uRenderEncoder setFragmentTexture:albedoTexture atIndex:0];
        [uRenderEncoder setFragmentTexture:normalTexture atIndex:1];
        [uRenderEncoder setFragmentTexture:positionTexture atIndex:2];
       
        //set lights info here
        
        [uRenderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:sizeof(quadVertices)/sizeof(quadVertices[0])];
        
    }

}
