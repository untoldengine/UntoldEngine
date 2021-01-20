//
//  U4DRenderShaderEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderShaderEntity.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DCamera.h"
#include "U4DResourceLoader.h"
#include "U4DNumerical.h"
#include "U4DLogger.h"
#include <iostream>

namespace U4DEngine {

    U4DRenderShaderEntity::U4DRenderShaderEntity(U4DShaderEntity *uU4DShaderEntity): uniformShaderEntityPropertyBuffer(nil),textureObject{nil,nil,nil,nil},samplerStateObject{nil,nil,nil,nil},samplerDescriptor{nullptr,nullptr,nullptr,nullptr}{
        
        u4dObject=uU4DShaderEntity;
        
        //It seems we do need to init the texture objects with a null descriptor
        initTextureSamplerObjectNull();
        
    }
    
    U4DRenderShaderEntity::~U4DRenderShaderEntity(){
        
        uniformShaderEntityPropertyBuffer=nil;
        
        for(int i=0;i<4;i++){
            
            [textureObject[i] setPurgeableState:MTLPurgeableStateEmpty];
            [textureObject[i] release];
            
            [samplerStateObject[i] release];
            
            textureObject[i]=nil;
            samplerStateObject[i]=nil;
            
            if (samplerDescriptor[i]!=nullptr) {
                [samplerDescriptor[i] release];
            }
            
        }
        
    }
    
    bool U4DRenderShaderEntity::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedShaderEntityData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRenderShaderEntity::loadMTLTexture(){
        
        //TODO: THIS SECTION NEEDS TO BE CLEANED.
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        if (!u4dObject->textureInformation.texture0.empty()){
            
            if(resourceLoader->loadTextureDataToEntity(this, u4dObject->textureInformation.texture0.c_str())){
                
                createTextureObject(textureObject[0]);
                
                createSamplerObject(samplerStateObject[0],samplerDescriptor[0]);
                
                clearRawImageData();
                
                u4dObject->setHasTexture(true);
                
            }
               
        }
        
        if (!u4dObject->textureInformation.texture1.empty()) {
           
            if(resourceLoader->loadTextureDataToEntity(this, u4dObject->textureInformation.texture1.c_str())){
                
                createTextureObject(textureObject[1]);
                
                createSamplerObject(samplerStateObject[1],samplerDescriptor[1]);
                
                clearRawImageData();
                
            }
            
        }
        
    }
    
    void U4DRenderShaderEntity::updateSpaceUniforms(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=u4dObject->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
        
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
        
        U4DNumerical numerical;
        
        matrix_float4x4 mvpSpaceSIMD=numerical.convertToSIMD(mvpSpace);
        
        
        UniformSpace uniformSpace;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRenderShaderEntity::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            updateSpaceUniforms();
            
            //update the global uniforms
            
            updateShaderEntityParams();
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:viSpaceBuffer];
            
            [uRenderEncoder setFragmentBuffer:uniformShaderEntityPropertyBuffer offset:propertiesTripleBuffer.offset atIndex:fiShaderEntityPropertyBuffer];
            
            [uRenderEncoder setFragmentTexture:textureObject[0] atIndex:fiTexture0];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject[0] atIndex:fiSampler0];
            
            [uRenderEncoder setFragmentTexture:textureObject[1] atIndex:fiTexture1];
            
            [uRenderEncoder setFragmentSamplerState:samplerStateObject[1] atIndex:fiSampler1];
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }

    void U4DRenderShaderEntity::updateShaderEntityParams(){
        
        U4DNumerical numerical;
        
        propertiesTripleBuffer.index = (propertiesTripleBuffer.index + 1) % U4DEngine::kMaxBuffersInFlight;
        
        propertiesTripleBuffer.offset = U4DEngine::kAlignedUniformShaderPropertySize * propertiesTripleBuffer.index;
        
        propertiesTripleBuffer.address = ((uint8_t*)uniformShaderEntityPropertyBuffer.contents) + propertiesTripleBuffer.offset;
        
        int sizeOfShaderParameterVector=(int)u4dObject->getShaderParameterContainer().size();
        
        UniformShaderEntityProperty *uniformShaderEntityProperty=(UniformShaderEntityProperty*)propertiesTripleBuffer.address;
        
        for(int i=0;i<sizeOfShaderParameterVector;i++){
        
            //load param1
            U4DVector4n shaderParameter=u4dObject->getShaderParameterContainer().at(i);
            
            vector_float4 shaderParameterSIMD=numerical.convertToSIMD(shaderParameter);
            
            uniformShaderEntityProperty->shaderParameter[i]=shaderParameterSIMD;
            
        }
        
        uniformShaderEntityProperty->hasTexture=u4dObject->getHasTexture();
        //memcpy(uniformShaderEntityPropertyBuffer.contents,(void*)&uniformShaderEntityProperty, sizeof(UniformShaderEntityProperty));
        
    }

    void U4DRenderShaderEntity::loadMTLAdditionalInformation(){
        
        //load additional information
        NSUInteger dynamicUniformShaderPropertyBuffer=U4DEngine::kAlignedUniformShaderPropertySize*U4DEngine::kMaxBuffersInFlight; 
        
        uniformShaderEntityPropertyBuffer=[mtlDevice newBufferWithLength:dynamicUniformShaderPropertyBuffer options:MTLResourceStorageModeShared];
    
    }
    
    void U4DRenderShaderEntity::alignedAttributeData(){
        
        AttributeAlignedShaderEntityData attributeAlignedData;
        U4DNumerical numerical;
        
        std::vector<AttributeAlignedShaderEntityData> attributeAlignedContainerTemp(u4dObject->bodyCoordinates.getVerticesDataFromContainer().size(),attributeAlignedData);

        attributeAlignedContainer=attributeAlignedContainerTemp;
        
        for(int i=0;i<attributeAlignedContainer.size();i++){
            
            U4DVector3n vertexData=u4dObject->bodyCoordinates.verticesContainer.at(i);
            
            attributeAlignedContainer.at(i).position.xyz=numerical.convertToSIMD(vertexData);
            attributeAlignedContainer.at(i).position.w=1.0;
            
            U4DVector2n uvData=u4dObject->bodyCoordinates.uVContainer.at(i);
            
            attributeAlignedContainer.at(i).uv.xy=numerical.convertToSIMD(uvData);
            
        }
        
    }
    
    void U4DRenderShaderEntity::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
    }

    void U4DRenderShaderEntity::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject[0]=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null texture sampler object
        nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject[0]=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
        
        //Do the same for the second texture object
        textureObject[1]=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        samplerStateObject[1]=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
    }

}
