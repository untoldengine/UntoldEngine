//
//  U4DRenderGeometry.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/11/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include "U4DRenderLights.h"

#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DRenderLights::U4DRenderLights(U4DLights *uU4DLights){
        
        u4dObject=uU4DLights;
    }
    
    U4DRenderLights::~U4DRenderLights(){
        
    }
    
    U4DDualQuaternion U4DRenderLights::getEntitySpace(){
        
        return u4dObject->getLocalSpace();
        
    }
    
    void U4DRenderLights::initMTLRenderLibrary(){
        
        mtlLibrary=[mtlDevice newDefaultLibrary];
        
        std::string vertexShaderName=u4dObject->getVertexShader();
        std::string fragmentShaderName=u4dObject->getFragmentShader();
        
        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
        
    }
    
    void U4DRenderLights::initMTLRenderPipeline(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        mtlRenderPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;
        
        //set the vertex descriptors
        
        MTLVertexDescriptor* vertexDesc=[[MTLVertexDescriptor alloc] init];
        
        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;
        
        //stride
        vertexDesc.layouts[0].stride=4*sizeof(float);
        
        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
        
        mtlRenderPipelineDescriptor.vertexDescriptor=vertexDesc;
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        
        
        MTLDepthStencilDescriptor *depthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
        depthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;
        
        depthStencilDescriptor.depthWriteEnabled=YES;
        
        depthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        
        //create the rendering pipeline object
        
        mtlRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPipelineDescriptor error:nil];
        
    }
    
    bool U4DRenderLights::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedLightData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderLights::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=getEntitySpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n worldSpace(1,0,0,0,
                               0,1,0,0,
                               0,0,1,0,
                               0,0,0,1);
        
        //YOU NEED TO MODIFY THIS SO THAT IT USES THE U4DCAMERA Position
        U4DEngine::U4DMatrix4n viewSpace=camera->getLocalSpace().transformDualQuaternionToMatrix4n();
        viewSpace.invert();

        U4DMatrix4n modelWorldSpace=worldSpace*modelSpace;
        
        U4DMatrix4n modelWorldViewSpace=viewSpace*modelWorldSpace;
        
        U4DMatrix4n perspectiveProjection=director->getPerspectiveSpace();
        
        U4DMatrix4n mvpSpace=perspectiveProjection*modelWorldViewSpace;
        
        
        matrix_float4x4 mvpSpaceSIMD=convertToSIMD(mvpSpace);
        
        
        UniformSpace uniformSpace;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderLights::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeLineStrip indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }
    
    void U4DRenderLights::alignedAttributeData(){
        
        for(int i=0;i<u4dObject->bodyCoordinates.getVerticesDataFromContainer().size();i++){
            
            AttributeAlignedLightData attributeAlignedData;
            
            attributeAlignedData.position.x=u4dObject->bodyCoordinates.verticesContainer.at(i).x;
            attributeAlignedData.position.y=u4dObject->bodyCoordinates.verticesContainer.at(i).y;
            attributeAlignedData.position.z=u4dObject->bodyCoordinates.verticesContainer.at(i).z;
            attributeAlignedData.position.w=1.0;
            
            attributeAlignedContainer.push_back(attributeAlignedData);
        }
        
    }
    
    void U4DRenderLights::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        
    }
    
    
}
