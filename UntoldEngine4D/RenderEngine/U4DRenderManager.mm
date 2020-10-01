//
//  RenderManager.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 6/30/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderManager.h"
#include "U4DDirector.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DShaderProtocols.h"
#include <simd/simd.h>
#include "U4DLogger.h"

namespace U4DEngine {

U4DRenderManager::U4DRenderManager():eligibleToRender(false),isWithinFrustum(false),mtlDevice(nil),mtlRenderPipelineState(nil),depthStencilState(nil),mtlRenderPipelineDescriptor(nil),mtlLibrary(nil),vertexProgram(nil),fragmentProgram(nil),vertexDesc(nil),depthStencilDescriptor(nil),attributeBuffer(nil),indicesBuffer(nil),uniformSpaceBuffer(nil),uniformModelRenderFlagsBuffer(nil),normalMapTextureObject(nil),samplerNormalMapStateObject(nil),lightPositionUniform(nil),lightColorUniform(nil),uniformParticleSystemPropertyBuffer(nil),uniformParticlePropertyBuffer(nil), uniformShaderEntityPropertyBuffer(nil),uniformModelShaderParametersBuffer(nil),globalDataUniform(nil),textureObject{nil,nil,nil,nil},samplerStateObject{nil,nil,nil,nil},samplerDescriptor{nullptr,nullptr,nullptr,nullptr},normalSamplerDescriptor(nil){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        mtlDevice=director->getMTLDevice();
        
        
    }
    
    U4DRenderManager::~U4DRenderManager(){

        [mtlRenderPipelineDescriptor release];
        [vertexDesc release];
        [depthStencilDescriptor release];
        [mtlRenderPipelineState release];
        [mtlLibrary release];
        
        
        
        mtlRenderPipelineDescriptor=nil;
        vertexDesc=nil;
        depthStencilDescriptor=nil;
        mtlLibrary=nil;
        mtlRenderPipelineState=nil;
        depthStencilState=nil;
        vertexProgram=nil;
        fragmentProgram=nil;
        attributeBuffer=nil;
        indicesBuffer=nil;
        uniformSpaceBuffer=nil;
        uniformModelRenderFlagsBuffer=nil;
        normalMapTextureObject=nil;
        samplerNormalMapStateObject=nil;
        
        lightPositionUniform=nil;
        lightColorUniform=nil;
        uniformParticlePropertyBuffer=nil;
        uniformParticleSystemPropertyBuffer=nil;
        uniformShaderEntityPropertyBuffer=nil;
        uniformModelShaderParametersBuffer=nil;
        globalDataUniform=nil;
        
        for(int i=0;i<4;i++){
            
            textureObject[i]=nil;
            samplerStateObject[i]=nil;
            
            if (samplerDescriptor[i]!=nullptr) {
                [samplerDescriptor[i] release];
            }
            
        }
        
        if (normalSamplerDescriptor!=nil) {
            [normalSamplerDescriptor release];
        }
        
    }
    
    void U4DRenderManager::loadRenderingInformation(){
        
        initMTLRenderLibrary();
        initMTLRenderPipeline();
        
        if(loadMTLBuffer()){
            
            loadMTLTexture();
            
            //loads additional information such as normal map, bones, etc if it exists.
            loadMTLAdditionalInformation();
            
            //load global uniform
            loadMTLGlobalDataUniforms();
            
            //clear all model attribute data
            clearModelAttributeData();
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No rendering data was found for the object. This object will not be rendered by the engine");
            
        }
        
    }
    
    void U4DRenderManager::clearRawImageData(){
        
        imageWidth=0;
        imageHeight=0;
        rawImageData.clear();
    }
    
    void U4DRenderManager::createTextureObject(id<MTLTexture> &uTextureObject){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *textureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the texture object
        uTextureObject=[mtlDevice newTextureWithDescriptor:textureDescriptor];
        
        //Copy the raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [uTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
    }
    
    void U4DRenderManager::createSamplerObject(id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor){
        
        //Create a sampler descriptor
        
        uSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        //Set the filtering and addressing settings
        uSamplerDescriptor.minFilter=MTLSamplerMinMagFilterLinear;
        uSamplerDescriptor.magFilter=MTLSamplerMinMagFilterLinear;
        
        //set the addressing mode for the S component
        uSamplerDescriptor.sAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //set the addressing mode for the T component
        uSamplerDescriptor.tAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //Create the sampler state object
        
        uSamplerStateObject=[mtlDevice newSamplerStateWithDescriptor:uSamplerDescriptor];
        
    }
    
    void U4DRenderManager::createNormalMapTextureObject(){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *normalMapTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the normal texture object
        normalMapTextureObject=[mtlDevice newTextureWithDescriptor:normalMapTextureDescriptor];
        
        //Copy the normal map raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [normalMapTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
        
    }
    
    void U4DRenderManager::createNormalMapSamplerObject(){
        
        //Create a sampler descriptor
        
        normalSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        //Set the filtering and addressing settings
        normalSamplerDescriptor.minFilter=MTLSamplerMinMagFilterLinear;
        normalSamplerDescriptor.magFilter=MTLSamplerMinMagFilterLinear;
        
        //set the addressing mode for the S component
        normalSamplerDescriptor.sAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //set the addressing mode for the T component
        normalSamplerDescriptor.tAddressMode=MTLSamplerAddressModeClampToEdge;
        
        //Create the sampler state object
        
        samplerNormalMapStateObject=[mtlDevice newSamplerStateWithDescriptor:normalSamplerDescriptor];
        
    }
    
    void U4DRenderManager::addTexturesToSkyboxContainer(const char* uTextures){
        
        skyboxTexturesContainer.push_back(uTextures);
    }
    
    std::vector<const char*> U4DRenderManager::getSkyboxTexturesContainer(){
        
        return skyboxTexturesContainer;
        
    }
    
    
    matrix_float4x4 U4DRenderManager::convertToSIMD(U4DEngine::U4DMatrix4n &uMatrix){
        
        // 4x4 matrix - column major. X vector is 0, 1, 2, etc.
        //	0	4	8	12
        //	1	5	9	13
        //	2	6	10	14
        //	3	7	11	15
        
        matrix_float4x4 m;
        
        m.columns[0][0]=uMatrix.matrixData[0];
        m.columns[0][1]=uMatrix.matrixData[1];
        m.columns[0][2]=uMatrix.matrixData[2];
        m.columns[0][3]=uMatrix.matrixData[3];
        
        m.columns[1][0]=uMatrix.matrixData[4];
        m.columns[1][1]=uMatrix.matrixData[5];
        m.columns[1][2]=uMatrix.matrixData[6];
        m.columns[1][3]=uMatrix.matrixData[7];
        
        m.columns[2][0]=uMatrix.matrixData[8];
        m.columns[2][1]=uMatrix.matrixData[9];
        m.columns[2][2]=uMatrix.matrixData[10];
        m.columns[2][3]=uMatrix.matrixData[11];
        
        m.columns[3][0]=uMatrix.matrixData[12];
        m.columns[3][1]=uMatrix.matrixData[13];
        m.columns[3][2]=uMatrix.matrixData[14];
        m.columns[3][3]=uMatrix.matrixData[15];
        
        return m;
        
    }
    
    matrix_float3x3 U4DRenderManager::convertToSIMD(U4DEngine::U4DMatrix3n &uMatrix){
        
        //	0	3	6
        //	1	4	7
        //	2	5	8
        
        matrix_float3x3 m;
        
        m.columns[0][0]=uMatrix.matrixData[0];
        m.columns[0][1]=uMatrix.matrixData[1];
        m.columns[0][2]=uMatrix.matrixData[2];
        
        m.columns[1][0]=uMatrix.matrixData[3];
        m.columns[1][1]=uMatrix.matrixData[4];
        m.columns[1][2]=uMatrix.matrixData[5];
        
        m.columns[2][0]=uMatrix.matrixData[6];
        m.columns[2][1]=uMatrix.matrixData[7];
        m.columns[2][2]=uMatrix.matrixData[8];
        
        return m;
        
    }
    
    vector_float4 U4DRenderManager::convertToSIMD(U4DEngine::U4DVector4n &uVector){
        
        vector_float4 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        v.z=uVector.z;
        v.w=uVector.w;
        
        return v;
    }
    
    vector_float3 U4DRenderManager::convertToSIMD(U4DEngine::U4DVector3n &uVector){
        
        vector_float3 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        v.z=uVector.z;
        
        return v;
    }
    
    vector_float2 U4DRenderManager::convertToSIMD(U4DEngine::U4DVector2n &uVector){
        
        vector_float2 v;
        
        v.x=uVector.x;
        v.y=uVector.y;
        
        return v;
    }

    void U4DRenderManager::setIsWithinFrustum(bool uValue){
        
        if(uValue==true){
            
            U4DDirector *director=U4DDirector::sharedInstance();
            
            director->setModelsWithinFrustum(true);
            
        }
        
        isWithinFrustum=uValue;
        
    }
    
    void U4DRenderManager::loadMTLGlobalDataUniforms(){
        
        globalDataUniform=[mtlDevice newBufferWithLength:sizeof(UniformGlobalData) options:MTLResourceStorageModeShared];
        
    }
    
    void U4DRenderManager::updateGlobalDataUniforms(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DScene *scene=sceneManager->getCurrentScene();
        
        //get the resolution of the display
        U4DVector2n resolution(director->getDisplayWidth(),director->getDisplayHeight());
        
        vector_float2 resolutionSIMD=convertToSIMD(resolution);
        
        UniformGlobalData uniformGlobalData;
        uniformGlobalData.time=scene->getGlobalTime(); //set the global time
        uniformGlobalData.resolution=resolutionSIMD; //set the display resolution
        
        memcpy(globalDataUniform.contents, (void*)&uniformGlobalData, sizeof(UniformGlobalData));
        
    }

    void U4DRenderManager::setRawImageData(std::vector<unsigned char> uRawImageData){
            
            rawImageData=uRawImageData;
            
        }

    void U4DRenderManager::setImageWidth(unsigned int uImageWidth){
        
        imageWidth=uImageWidth;
        
    }

    void U4DRenderManager::setImageHeight(unsigned int uImageHeight){
        
        imageHeight=uImageHeight;
    }

}

