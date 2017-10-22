//
//  U4DRenderParticleSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/9/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DRenderParticleSystem.h"

#include "U4DShaderProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DMaterialData.h"
#include "U4DColorData.h"

namespace U4DEngine {
    
    U4DRenderParticleSystem::U4DRenderParticleSystem(U4DParticleSystem *uU4DParticleSystem){
        
        u4dObject=uU4DParticleSystem;
        
        initTextureSamplerObjectNull();
    }
    
    U4DRenderParticleSystem::~U4DRenderParticleSystem(){
        
    }
    
    U4DDualQuaternion U4DRenderParticleSystem::getEntitySpace(){
        
        return u4dObject->getAbsoluteSpace();
        
    }
    
    U4DDualQuaternion U4DRenderParticleSystem::getEntityLocalSpace(){
        
        return u4dObject->getLocalSpace();
        
    }
    
    U4DVector3n U4DRenderParticleSystem::getEntityAbsolutePosition(){
        
        
        return u4dObject->getAbsolutePosition();
        
    }
    
    U4DVector3n U4DRenderParticleSystem::getEntityLocalPosition(){
        
        return u4dObject->getLocalPosition();
        
    }
    
    
    void U4DRenderParticleSystem::initMTLRenderLibrary(){
        
        mtlLibrary=[mtlDevice newDefaultLibrary];
        
        std::string vertexShaderName=u4dObject->getVertexShader();
        std::string fragmentShaderName=u4dObject->getFragmentShader();
        
        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
        
    }
    
    void U4DRenderParticleSystem::initMTLRenderPipeline(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        
        mtlRenderPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;
        
        mtlRenderPipelineDescriptor.colorAttachments[0].blendingEnabled=YES;
        mtlRenderPipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;
        mtlRenderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;
        mtlRenderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOne;
        
        mtlRenderPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
        mtlRenderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;
        mtlRenderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;

        //set the vertex descriptors
        
        MTLVertexDescriptor* vertexDesc=[[MTLVertexDescriptor alloc] init];
        
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
        
        
        mtlRenderPipelineDescriptor.vertexDescriptor=vertexDesc;
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        
        
        MTLDepthStencilDescriptor *depthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
        depthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;
        
        depthStencilDescriptor.depthWriteEnabled=NO;
        
        //        //add stencil description
        //        MTLStencilDescriptor *stencilStateDescriptor=[[MTLStencilDescriptor alloc] init];
        //        stencilStateDescriptor.stencilCompareFunction=MTLCompareFunctionAlways;
        //        stencilStateDescriptor.stencilFailureOperation=MTLStencilOperationKeep;
        //
        //        depthStencilDescriptor.frontFaceStencil=stencilStateDescriptor;
        //        depthStencilDescriptor.backFaceStencil=stencilStateDescriptor;
        
        
        //create depth stencil state
        depthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:depthStencilDescriptor];
        
        
        //create the rendering pipeline object
        mtlRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPipelineDescriptor error:nil];
        
    }
    
    bool U4DRenderParticleSystem::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            return false;
        }
        
        int maxNumberOfParticles=u4dObject->getMaxNumberOfParticles();
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedParticleData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace)*maxNumberOfParticles options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderParticleSystem::loadMTLTexture(){
        
        if (!u4dObject->textureInformation.diffuseTexture.empty()){
            
            decodeImage(u4dObject->textureInformation.diffuseTexture);
            
            createTextureObject();
            
            createSamplerObject();
            
            u4dObject->setHasTexture(true);
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No data found for the Image Texture");
            
        }
        
        clearRawImageData();
        
    }
    
    void U4DRenderParticleSystem::loadParticlePropertiesInformation(){
        
        int maxNumberOfParticles=u4dObject->getMaxNumberOfParticles();
        
        uniformParticlePropertyBuffer=[mtlDevice newBufferWithLength:sizeof(UniformParticleProperty)*maxNumberOfParticles options:MTLResourceStorageModeShared];
    }
    
    void U4DRenderParticleSystem::loadParticleSystemPropertiesInformation(){
        
        uniformParticleSystemPropertyBuffer=[mtlDevice newBufferWithLength:sizeof(UniformParticleSystemProperty) options:MTLResourceStorageModeShared];
        
        bool hasTexture=u4dObject->getHasTexture();
        
        UniformParticleSystemProperty uniformParticleSystemProperty;
        
        uniformParticleSystemProperty.hasTexture=hasTexture;
        
        memcpy(uniformParticleSystemPropertyBuffer.contents,(void*)&uniformParticleSystemProperty, sizeof(UniformParticleSystemProperty));
        
    }

    void U4DRenderParticleSystem::loadMTLAdditionalInformation(){
        
        //load additional information
        
        loadParticleSystemPropertiesInformation();
        
        loadParticlePropertiesInformation();
    
    }
    
    void U4DRenderParticleSystem::setDiffuseTexture(const char* uTexture){
        
        u4dObject->textureInformation.diffuseTexture=uTexture;
        
    }
    
    void U4DRenderParticleSystem::updateParticlePropertiesInformation(){
        
        int numberOfEmittedParticles=u4dObject->getNumberOfEmittedParticles();
        
        UniformParticleProperty uniformParticleProperty[numberOfEmittedParticles];
        
        for(int i=0;i<numberOfEmittedParticles;i++){
            
            U4DVector3n color=u4dObject->getParticleContainer().at(i).color;
            
            vector_float3 colorSIMD=convertToSIMD(color);
            
            uniformParticleProperty[i].color=colorSIMD;
            
        }
        
        memcpy(uniformParticlePropertyBuffer.contents,(void*)&uniformParticleProperty, sizeof(UniformParticleProperty)*numberOfEmittedParticles);
        
    }
    
    void U4DRenderParticleSystem::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        int numberOfEmittedParticles=u4dObject->getNumberOfEmittedParticles();
        
        UniformSpace uniformSpace[numberOfEmittedParticles];
        
        for(int i=0;i<numberOfEmittedParticles;i++){
            
            U4DMatrix4n modelSpace=u4dObject->getParticleContainer().at(i).absoluteSpace;
        
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
            
            //Conver to SIMD
            matrix_float4x4 modelSpaceSIMD=convertToSIMD(modelSpace);
            matrix_float4x4 worldModelSpaceSIMD=convertToSIMD(worldSpace);
            matrix_float4x4 viewWorldModelSpaceSIMD=convertToSIMD(modelWorldViewSpace);
            matrix_float4x4 viewSpaceSIMD=convertToSIMD(viewSpace);
            matrix_float4x4 mvpSpaceSIMD=convertToSIMD(mvpSpace);
            
            
            uniformSpace[i].modelSpace=modelSpaceSIMD;
            uniformSpace[i].viewSpace=viewSpaceSIMD;
            uniformSpace[i].modelViewSpace=viewWorldModelSpaceSIMD;
            uniformSpace[i].modelViewProjectionSpace=mvpSpaceSIMD;
            
        }

        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace)*numberOfEmittedParticles);
        
    }
    
    void U4DRenderParticleSystem::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        int numberOfEmittedParticles=u4dObject->getNumberOfEmittedParticles();
        
        if (eligibleToRender==true && numberOfEmittedParticles>0) {
            
            updateSpaceUniforms();
            updateParticlePropertiesInformation();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            [uRenderEncoder setVertexBuffer:uniformParticlePropertyBuffer offset:0 atIndex:2];
    
            //encode buffer in fragment
            [uRenderEncoder setFragmentBuffer:uniformParticleSystemPropertyBuffer offset:0 atIndex:0];
            
            //set texture in fragment
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            
            //set the samplers
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0 instanceCount:u4dObject->getNumberOfEmittedParticles()];
            
        }
        
        
    }
    
    void U4DRenderParticleSystem::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null texture sampler object
        MTLSamplerDescriptor *nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
    }
    
    void U4DRenderParticleSystem::alignedAttributeData(){
        
        for(int i=0;i<u4dObject->bodyCoordinates.getVerticesDataFromContainer().size();i++){
            
            AttributeAlignedParticleData attributeAlignedData;
            
            attributeAlignedData.position.x=u4dObject->bodyCoordinates.verticesContainer.at(i).x;
            attributeAlignedData.position.y=u4dObject->bodyCoordinates.verticesContainer.at(i).y;
            attributeAlignedData.position.z=u4dObject->bodyCoordinates.verticesContainer.at(i).z;
            attributeAlignedData.position.w=1.0;
            
            attributeAlignedContainer.push_back(attributeAlignedData);
        }
        
        if (u4dObject->bodyCoordinates.uVContainer.size()>0) {
            
            for(int i=0; i<attributeAlignedContainer.size();i++){
                
                attributeAlignedContainer.at(i).uv.x=u4dObject->bodyCoordinates.uVContainer.at(i).x;
                attributeAlignedContainer.at(i).uv.y=u4dObject->bodyCoordinates.uVContainer.at(i).y;
                attributeAlignedContainer.at(i).uv.z=0.0;
                attributeAlignedContainer.at(i).uv.w=0.0;
            }
            
        }
        
    }
    
    void U4DRenderParticleSystem::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
        
    }
    
}
