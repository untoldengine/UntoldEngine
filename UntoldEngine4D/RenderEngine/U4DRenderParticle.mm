//
//  U4DRenderParticle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/9/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U4DRenderParticle.h"

#include "U4DShaderProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DMaterialData.h"
#include "U4DColorData.h"

namespace U4DEngine {
    
    U4DRenderParticle::U4DRenderParticle(U4DParticle *uU4DParticle){
        
        u4dObject=uU4DParticle;
        
        initTextureSamplerObjectNull();
    }
    
    U4DRenderParticle::~U4DRenderParticle(){
        
    }
    
    U4DDualQuaternion U4DRenderParticle::getEntitySpace(){
        
        return u4dObject->getAbsoluteSpace();
        
    }
    
    U4DDualQuaternion U4DRenderParticle::getEntityLocalSpace(){
        
        return u4dObject->getLocalSpace();
        
    }
    
    U4DVector3n U4DRenderParticle::getEntityAbsolutePosition(){
        
        
        return u4dObject->getAbsolutePosition();
        
    }
    
    U4DVector3n U4DRenderParticle::getEntityLocalPosition(){
        
        return u4dObject->getLocalPosition();
        
    }
    
    
    void U4DRenderParticle::initMTLRenderLibrary(){
        
        mtlLibrary=[mtlDevice newDefaultLibrary];
        
        std::string vertexShaderName=u4dObject->getVertexShader();
        std::string fragmentShaderName=u4dObject->getFragmentShader();
        
        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
        
    }
    
    void U4DRenderParticle::initMTLRenderPipeline(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        
        mtlRenderPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;
        
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
        
        depthStencilDescriptor.depthWriteEnabled=YES;
        
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
    
    bool U4DRenderParticle::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedParticleData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderParticle::loadMTLTexture(){
        
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
    
    void U4DRenderParticle::loadParticlePropertiesInformation(){
        
        uniformParticlePropertyBuffer=[mtlDevice newBufferWithLength:sizeof(UniformParticleProperty) options:MTLResourceStorageModeShared];
        
        UniformParticleProperty uniformParticleProperty;
        
        U4DVector4n diffuseColor=u4dObject->getDiffuseColor();
        
        vector_float4 diffuseColorSIMD=convertToSIMD(diffuseColor);
        
        uniformParticleProperty.diffuseColor=diffuseColorSIMD;
        uniformParticleProperty.hasTexture=u4dObject->getHasTexture();
        uniformParticleProperty.particleLifeTime=u4dObject->getParticleLifetime();
        
        memcpy(uniformParticlePropertyBuffer.contents,(void*)&uniformParticleProperty, sizeof(UniformParticleProperty));
        
    }
    
    void U4DRenderParticle::loadParticleInstancePropertiesInformation(){
        
        int numberOfParticles=u4dObject->getNumberOfParticles();
        
        uniformParticleInstanceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformParticleInstanceProperty)*numberOfParticles options:MTLResourceStorageModeShared];

        UniformParticleInstanceProperty uniformParticleInstanceProperty[numberOfParticles];
        
        for(int i=0;i<numberOfParticles;i++){
            
            U4DVector3n velocity=u4dObject->particleData.getVelocityDataFromContainer().at(i);
            float time=u4dObject->particleData.getStartTimeDataFromContainer().at(i);
            
            uniformParticleInstanceProperty[i].velocity=convertToSIMD(velocity);
            uniformParticleInstanceProperty[i].time=time;
            
        }
        
        memcpy(uniformParticleInstanceBuffer.contents,(void*)&uniformParticleInstanceProperty, sizeof(UniformParticleInstanceProperty)*numberOfParticles);
        
        //clear the particle properties. It is not needed anymore
        clearParticleData();
    }
    
    void U4DRenderParticle::loadParticleAnimationInformation(){
        
        uniformParticleAnimationBuffer=[mtlDevice newBufferWithLength:sizeof(UniformParticleAnimation) options:MTLResourceStorageModeShared];
        
    }
    
    void U4DRenderParticle::updateParticleAnimationTime(){
        
        UniformParticleAnimation particleAnimation;
        
        particleAnimation.time=u4dObject->getParticleAnimationElapsedTime();
        
        memcpy(uniformParticleAnimationBuffer.contents, (void*)&particleAnimation, sizeof(UniformParticleAnimation));
        
    }
    
    void U4DRenderParticle::loadMTLAdditionalInformation(){
        
        //load additional information
        loadParticlePropertiesInformation();
        
        loadParticleInstancePropertiesInformation();
        
        loadParticleAnimationInformation();
    }
    
    void U4DRenderParticle::setDiffuseTexture(const char* uTexture){
        
        u4dObject->textureInformation.diffuseTexture=uTexture;
        
    }
    
    
    void U4DRenderParticle::updateSpaceUniforms(){
        
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
        
        //Conver to SIMD
        matrix_float4x4 modelSpaceSIMD=convertToSIMD(modelSpace);
        matrix_float4x4 worldModelSpaceSIMD=convertToSIMD(worldSpace);
        matrix_float4x4 viewWorldModelSpaceSIMD=convertToSIMD(modelWorldViewSpace);
        matrix_float4x4 viewSpaceSIMD=convertToSIMD(viewSpace);
        matrix_float4x4 mvpSpaceSIMD=convertToSIMD(mvpSpace);
        
        UniformSpace uniformSpace;
        uniformSpace.modelSpace=modelSpaceSIMD;
        uniformSpace.viewSpace=viewSpaceSIMD;
        uniformSpace.modelViewSpace=viewWorldModelSpaceSIMD;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderParticle::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            updateParticleAnimationTime();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            [uRenderEncoder setVertexBuffer:uniformParticleInstanceBuffer offset:0 atIndex:2];
            
            [uRenderEncoder setVertexBuffer:uniformParticleAnimationBuffer offset:0 atIndex:3];
            
            [uRenderEncoder setVertexBuffer:uniformParticlePropertyBuffer offset:0 atIndex:4];
    
            
            //set the buffers in the fragment
            [uRenderEncoder setFragmentBuffer:uniformParticlePropertyBuffer offset:0 atIndex:1];
            
            //set texture in fragment
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            
            //set the samplers
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0 instanceCount:u4dObject->getNumberOfParticles()];
            
        }
        
        
    }
    
    void U4DRenderParticle::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null texture sampler object
        MTLSamplerDescriptor *nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
    }
    
    void U4DRenderParticle::alignedAttributeData(){
        
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
    
    void U4DRenderParticle::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
        
    }
    
    void U4DRenderParticle::clearParticleData(){
        
        //clear the particle properties. It is not needed anymore
        u4dObject->particleData.getVelocityDataFromContainer().clear();
        u4dObject->particleData.getStartTimeDataFromContainer().clear();
        
    }
    
    
}
