//
//  U4DRenderImage.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#include "U4DRenderImage.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"

namespace U4DEngine {

    U4DRenderImage::U4DRenderImage(U4DImage *uU4DImage){
        
        u4dObject=uU4DImage;
    }
    
    U4DRenderImage::~U4DRenderImage(){
        
    }
    
    void U4DRenderImage::initMTLRenderLibrary(){
        
        mtlLibrary=[mtlDevice newDefaultLibrary];
        
        std::string vertexShaderName=u4dObject->getVertexShader();
        std::string fragmentShaderName=u4dObject->getFragmentShader();
        
        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
        
    }
    
    void U4DRenderImage::initMTLRenderPipeline(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        mtlRenderPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;

        mtlRenderPipelineDescriptor.colorAttachments[0].blendingEnabled=YES;
        mtlRenderPipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;
        mtlRenderPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
        mtlRenderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;
        mtlRenderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;
        mtlRenderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
        mtlRenderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;


        
        //set the vertex descriptors
        
        MTLVertexDescriptor* vertexDesc=[[MTLVertexDescriptor alloc] init];
        
        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
        vertexDesc.attributes[0].bufferIndex=0;
        vertexDesc.attributes[0].offset=0;
        
        vertexDesc.attributes[1].format=MTLVertexFormatFloat2;
        vertexDesc.attributes[1].bufferIndex=0;
        vertexDesc.attributes[1].offset=4*sizeof(float);
        
        //stride is 10 but must provide padding so it makes it 12
        vertexDesc.layouts[0].stride=8*sizeof(float);
        
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
    
    void U4DRenderImage::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedImageData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
    }
    
    void U4DRenderImage::loadMTLTexture(){
        
        if (!u4dObject->textureInformation.diffuseTexture.empty()){
            
            decodeImage(u4dObject->textureInformation.diffuseTexture);
            
            createTextureObject();
            
            createSamplerObject();
            
        }
        
        clearRawImageData();
        
    }
    
    void U4DRenderImage::setImageDimension(float uWidth,float uHeight){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //make a rectangle
        float width=uWidth/director->getDisplayWidth();
        float height=uHeight/director->getDisplayHeight();
        float depth=0.0;
        
        //vertices
        U4DEngine::U4DVector3n v1(width,height,depth);
        U4DEngine::U4DVector3n v4(width,-height,depth);
        U4DEngine::U4DVector3n v2(-width,-height,depth);
        U4DEngine::U4DVector3n v3(-width,height,depth);
        
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v1);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v4);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v2);
        u4dObject->bodyCoordinates.addVerticesDataToContainer(v3);
        
        
        //texture
        U4DEngine::U4DVector2n t4(0.0,0.0);  //top left
        U4DEngine::U4DVector2n t1(1.0,0.0);  //top right
        U4DEngine::U4DVector2n t3(0.0,1.0);  //bottom left
        U4DEngine::U4DVector2n t2(1.0,1.0);  //bottom right
        
        u4dObject->bodyCoordinates.addUVDataToContainer(t1);
        u4dObject->bodyCoordinates.addUVDataToContainer(t2);
        u4dObject->bodyCoordinates.addUVDataToContainer(t3);
        u4dObject->bodyCoordinates.addUVDataToContainer(t4);
        
        
        U4DEngine::U4DIndex i1(0,1,2);
        U4DEngine::U4DIndex i2(2,3,0);
        
        
        u4dObject->bodyCoordinates.addIndexDataToContainer(i1);
        u4dObject->bodyCoordinates.addIndexDataToContainer(i2);
        
    }
    
    void U4DRenderImage::setDiffuseTexture(const char* uTexture){
        
        u4dObject->textureInformation.diffuseTexture=uTexture;
        
    }
    
    U4DDualQuaternion U4DRenderImage::getEntitySpace(){
        return u4dObject->getLocalSpace();
    }
    
    void U4DRenderImage::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=getEntitySpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n worldSpace(1,0,0,0,
                               0,1,0,0,
                               0,0,1,0,
                               0,0,0,1);
        
        //YOU NEED TO MODIFY THIS SO THAT IT USES THE U4DCAMERA Position
        U4DEngine::U4DMatrix4n viewSpace;
        
        U4DMatrix4n modelWorldSpace=worldSpace*modelSpace;
        
        U4DMatrix4n modelWorldViewSpace=viewSpace*modelWorldSpace;
        
        U4DMatrix4n orthogonalProjection=director->getOrthographicSpace();
        
        U4DMatrix4n mvpSpace=orthogonalProjection*modelWorldViewSpace;
        
        
        matrix_float4x4 mvpSpaceSIMD=convertToSIMD(mvpSpace);
        
        
        UniformSpace uniformSpace;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderImage::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        updateSpaceUniforms();
        
        //encode the pipeline
        [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
        
        [uRenderEncoder setDepthStencilState:depthStencilState];
        
        //encode the buffers
        [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
        
        [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
        
        [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
        
        [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
        
        //set the draw command
        [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
        
    }
    
    void U4DRenderImage::alignedAttributeData(){
        
        for(int i=0;i<u4dObject->bodyCoordinates.getVerticesDataFromContainer().size();i++){
            
            AttributeAlignedImageData attributeAlignedData;
            
            attributeAlignedData.position.x=u4dObject->bodyCoordinates.verticesContainer.at(i).x;
            attributeAlignedData.position.y=u4dObject->bodyCoordinates.verticesContainer.at(i).y;
            attributeAlignedData.position.z=u4dObject->bodyCoordinates.verticesContainer.at(i).z;
            attributeAlignedData.position.w=1.0;
            
            attributeAlignedContainer.push_back(attributeAlignedData);
        }
        
        for(int i=0; i<attributeAlignedContainer.size();i++){
                        
            attributeAlignedContainer.at(i).uv.x=u4dObject->bodyCoordinates.uVContainer.at(i).x;
            attributeAlignedContainer.at(i).uv.y=u4dObject->bodyCoordinates.uVContainer.at(i).y;
            
        }
        
    }


}
