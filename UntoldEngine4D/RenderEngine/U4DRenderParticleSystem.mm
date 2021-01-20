//
//  U4DRenderParticleSystem.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/9/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderParticleSystem.h"

#include "U4DShaderProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DMaterialData.h"
#include "U4DColorData.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DRenderParticleSystem::U4DRenderParticleSystem(U4DParticleSystem *uU4DParticleSystem):nullSamplerDescriptor(nil),uniformParticleSystemPropertyBuffer(nil),uniformParticlePropertyBuffer(nil),textureObject{nil},samplerStateObject{nil},samplerDescriptor{nullptr}{
        
        u4dObject=uU4DParticleSystem;
        
        //It seems we do need to init the texture objects with a null descriptor
        initTextureSamplerObjectNull();
    }
    
    U4DRenderParticleSystem::~U4DRenderParticleSystem(){
        
        [nullSamplerDescriptor release];
        
        nullSamplerDescriptor=nil;
        
        [uniformParticlePropertyBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [uniformParticlePropertyBuffer release];
        
        [uniformParticleSystemPropertyBuffer setPurgeableState:MTLPurgeableStateEmpty];
        [uniformParticleSystemPropertyBuffer release];
        
        uniformParticlePropertyBuffer=nil;
        uniformParticleSystemPropertyBuffer=nil;
        
        [textureObject setPurgeableState:MTLPurgeableStateEmpty];
        [textureObject release];
      
        [samplerStateObject release];
        [samplerDescriptor release];
       
        textureObject=nil;
        samplerStateObject=nil;
        samplerDescriptor=nil;
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
        
        if (!u4dObject->textureInformation.texture0.empty() && rawImageData.size()>0){
            
            createTextureObject(textureObject);
            
            createSamplerObject(samplerStateObject,samplerDescriptor);
            
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
        
        bool enableNoise=u4dObject->getEnableNoise();
        
        float noiseDetail=u4dObject->getNoiseDetail();
        
        UniformParticleSystemProperty uniformParticleSystemProperty;
        
        uniformParticleSystemProperty.hasTexture=hasTexture;
        uniformParticleSystemProperty.enableNoise=enableNoise;
        uniformParticleSystemProperty.noiseDetail=noiseDetail;
        
        memcpy(uniformParticleSystemPropertyBuffer.contents,(void*)&uniformParticleSystemProperty, sizeof(UniformParticleSystemProperty));
        
    }

    void U4DRenderParticleSystem::loadMTLAdditionalInformation(){
        
        //load additional information
        
        loadParticleSystemPropertiesInformation();
        
        loadParticlePropertiesInformation();
    
    }
    
    
    void U4DRenderParticleSystem::updateParticlePropertiesInformation(){
        
        U4DNumerical numerical;
        
        int numberOfParticlesToRender=(int)u4dObject->getParticleRenderDataContainer().size();
        
        UniformParticleProperty uniformParticleProperty[numberOfParticlesToRender];
            
            for(int i=0;i<u4dObject->getParticleRenderDataContainer().size();i++){
                
                //load particle color
                U4DVector4n color=u4dObject->getParticleRenderDataContainer().at(i).color;
                
                vector_float4 colorSIMD=numerical.convertToSIMD(color);
                
                uniformParticleProperty[i].color=colorSIMD;
                
                //load particle scale
                uniformParticleProperty[i].scaleFactor=u4dObject->getParticleRenderDataContainer().at(i).scaleFactor;
                
                //load particle rotation
                uniformParticleProperty[i].rotationAngle=u4dObject->getParticleRenderDataContainer().at(i).rotationAngle;
                
            }
            
        memcpy(uniformParticlePropertyBuffer.contents,(void*)&uniformParticleProperty, sizeof(UniformParticleProperty)*numberOfParticlesToRender);
        
        
    }
    
    void U4DRenderParticleSystem::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        int numberOfParticlesToRender=(int)u4dObject->getParticleRenderDataContainer().size();
        
        UniformSpace uniformSpace[numberOfParticlesToRender];
        
        for(int i=0;i<u4dObject->getParticleRenderDataContainer().size();i++){
            
            U4DMatrix4n modelSpace=u4dObject->getParticleRenderDataContainer().at(i).absoluteSpace;
        
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
            U4DNumerical numerical;
            
            matrix_float4x4 modelSpaceSIMD=numerical.convertToSIMD(modelSpace);
            matrix_float4x4 worldModelSpaceSIMD=numerical.convertToSIMD(worldSpace);
            matrix_float4x4 viewWorldModelSpaceSIMD=numerical.convertToSIMD(modelWorldViewSpace);
            matrix_float4x4 viewSpaceSIMD=numerical.convertToSIMD(viewSpace);
            matrix_float4x4 mvpSpaceSIMD=numerical.convertToSIMD(mvpSpace);
            
            
            uniformSpace[i].modelSpace=modelSpaceSIMD;
            uniformSpace[i].viewSpace=viewSpaceSIMD;
            uniformSpace[i].modelViewSpace=viewWorldModelSpaceSIMD;
            uniformSpace[i].modelViewProjectionSpace=mvpSpaceSIMD;
            
        }

        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace)*numberOfParticlesToRender);
        
    }
    
    void U4DRenderParticleSystem::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        int numberOfParticlesToRender=(int)u4dObject->getParticleRenderDataContainer().size();
        
        if (eligibleToRender==true && numberOfParticlesToRender>0) {
            
            updateSpaceUniforms();
            updateParticlePropertiesInformation();
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:viSpaceBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformParticlePropertyBuffer offset:0 atIndex:viParticlesPropertiesBuffer];
            
            //encode buffer in fragment
            [uRenderEncoder setFragmentBuffer:uniformParticleSystemPropertyBuffer offset:0 atIndex:fiParticleSysPropertiesBuffer];
            
            //set texture in fragment
            [uRenderEncoder setFragmentTexture:textureObject atIndex:fiTexture0];
            
            //set the samplers
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:fiSampler0];
            
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0 instanceCount:numberOfParticlesToRender];
            
        }
        
        
    }
    
    void U4DRenderParticleSystem::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null texture sampler object
        nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
    }
    
    void U4DRenderParticleSystem::alignedAttributeData(){

        AttributeAlignedParticleData attributeAlignedData;
        U4DNumerical numerical;
        
        std::vector<AttributeAlignedParticleData> attributeAlignedContainerTemp(u4dObject->bodyCoordinates.getVerticesDataFromContainer().size(),attributeAlignedData);

        attributeAlignedContainer=attributeAlignedContainerTemp;

        bool alignUVContainer=false;
        if (u4dObject->bodyCoordinates.uVContainer.size()>0) alignUVContainer=true;

        for(int i=0;i<attributeAlignedContainer.size();i++){

            U4DVector3n vertexData=u4dObject->bodyCoordinates.verticesContainer.at(i);
            attributeAlignedContainer.at(i).position.xyz=numerical.convertToSIMD(vertexData);
            attributeAlignedContainer.at(i).position.w=1.0;

            if (alignUVContainer) {
                
                U4DVector2n uvData=u4dObject->bodyCoordinates.uVContainer.at(i);
                
                attributeAlignedContainer.at(i).uv.xy=numerical.convertToSIMD(uvData);
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
