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
#include <fstream> //for file i/o

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
    
//    void U4DRenderShaderEntity::initMTLRenderLibrary(){
//
//        mtlLibrary=[mtlDevice newDefaultLibrary];
//
//        std::string vertexShaderName=u4dObject->getVertexShader();
//        std::string fragmentShaderName=u4dObject->getFragmentShader();
//
//        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
//        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
//
//    }
//
//    void U4DRenderShaderEntity::initMTLRenderPipeline(){
//
//        U4DDirector *director=U4DDirector::sharedInstance();
//
//        mtlRenderPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
//        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
//        mtlRenderPipelineDescriptor.fragmentFunction=fragmentProgram;
//        mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
//
//        if(u4dObject->getEnableBlending()){
//            mtlRenderPipelineDescriptor.colorAttachments[0].blendingEnabled=YES;
//        }else{
//            mtlRenderPipelineDescriptor.colorAttachments[0].blendingEnabled=NO;
//        }
//
//        //rgb blending
//        mtlRenderPipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;
//
//        //original blend factor
//        //mtlRenderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceColor;
//        mtlRenderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;
//
//        if (u4dObject->getEnableAdditiveRendering()) {
//
//            mtlRenderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOne;
//
//        }else{
//
//            mtlRenderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
//
//        }
//
//        //alpha blending
//        mtlRenderPipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
//
//        mtlRenderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;
//
//        mtlRenderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
//
//
//        mtlRenderPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;
//
//        //set the vertex descriptors
//
//        vertexDesc=[[MTLVertexDescriptor alloc] init];
//
//        vertexDesc.attributes[0].format=MTLVertexFormatFloat4;
//        vertexDesc.attributes[0].bufferIndex=0;
//        vertexDesc.attributes[0].offset=0;
//
//        vertexDesc.attributes[1].format=MTLVertexFormatFloat2;
//        vertexDesc.attributes[1].bufferIndex=0;
//        vertexDesc.attributes[1].offset=4*sizeof(float);
//
//        //stride is 10 but must provide padding so it makes it 12
//        vertexDesc.layouts[0].stride=8*sizeof(float);
//
//        vertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
//
//
//        mtlRenderPipelineDescriptor.vertexDescriptor=vertexDesc;
//        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
//
//        depthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
//
//        depthStencilDescriptor.depthCompareFunction=MTLCompareFunctionLess;
//
//        depthStencilDescriptor.depthWriteEnabled=NO;
//
//        depthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:depthStencilDescriptor];
//
//        //create the rendering pipeline object
//
//        mtlRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlRenderPipelineDescriptor error:nil];
//
//    }

//    void U4DRenderShaderEntity::hotReloadShaders(std::string uFilepath){
//
//        //reload the library
//        U4DLogger *logger=U4DLogger::sharedInstance();
//
//        NSError *error;
//        std::ifstream ifs(uFilepath);
//
//        std::string shaderContent;
//        shaderContent.assign( (std::istreambuf_iterator<char>(ifs) ),
//                        (std::istreambuf_iterator<char>()));
//
//        NSString* shaderCode = [NSString stringWithUTF8String:shaderContent.c_str()];
//
//
////        NSString* filepathNSString = [NSString stringWithUTF8String:uFilepath.c_str()];
////
////        NSString *shaderCode= [NSString stringWithContentsOfFile:filepathNSString encoding:NSUTF8StringEncoding error:&error];
////
////        if(!shaderCode){
////            NSLog(@"Error: %@",error.localizedDescription);
////        }
//
//        id<MTLLibrary> tempMTLLibrary=[mtlDevice newLibraryWithSource:shaderCode options:nil error:&error];
//
//        if (!tempMTLLibrary) {
//
//            //NSLog(@"error loading file %@",error.localizedDescription);
//            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
//            logger->log("Error: loading the library for hot reloading. %s",errorDesc.c_str());
//
//        }else{
//
//            MTLRenderPipelineDescriptor *tempMTLRenderPipelineDescriptor;
//
//            //temporarily copy the library, shader program and descriptor until we know that the hot reload was a success
//
//            tempMTLRenderPipelineDescriptor=mtlRenderPipelineDescriptor;
//
//            std::string vertexShaderName=u4dObject->getVertexShader();
//            std::string fragmentShaderName=u4dObject->getFragmentShader();
//
//            id<MTLFunction> tempVertexProgram=[tempMTLLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
//            id<MTLFunction> tempFragmentProgram=[tempMTLLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
//
//             //since we already have a pointer to our pipeline descriptor, the only thing we need to update are the shader programs
//             tempMTLRenderPipelineDescriptor.vertexFunction=tempVertexProgram;
//             tempMTLRenderPipelineDescriptor.fragmentFunction=tempFragmentProgram;
//
//             //create the rendering pipeline object
//
//             id<MTLRenderPipelineState> tempMTLRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:tempMTLRenderPipelineDescriptor error:&error];
//
//            if(!tempMTLRenderPipelineState){
//
//                //NSLog(@"The pipeline was unable to be created: %@",error.localizedDescription);
//
//                std::string errorDesc= std::string([error.localizedDescription UTF8String]);
//                logger->log("Error: The pipeline was unable to be created. %s",errorDesc.c_str());
//
//            }else{
//
//                logger->log("The pipeline was updated");
//
//                mtlRenderPipelineDescriptor=tempMTLRenderPipelineDescriptor;
//                mtlRenderPipelineState=tempMTLRenderPipelineState;
//                vertexProgram=tempVertexProgram;
//                fragmentProgram=tempFragmentProgram;
//                mtlLibrary=tempMTLLibrary;
//
//            }
//
//        }
//
//    }
    
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
