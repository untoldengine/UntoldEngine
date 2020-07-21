//
//  U4DRender3DModel.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRender3DModel.h"
#include "U4DShaderProtocols.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DLights.h"
#include "U4DMaterialData.h"
#include "U4DColorData.h"
#include "U4DResourceLoader.h"

namespace U4DEngine {

    U4DRender3DModel::U4DRender3DModel(U4DModel *uU4DModel):shadowTexture(nil),uniformMaterialBuffer(nil),uniformBoneBuffer(nil),nullSamplerDescriptor(nil),shadowPropertiesBuffer(nil){
        
        u4dObject=uU4DModel;
        
        //It seems we do need to init the texture objects with a null descriptor
        //initTextureSamplerObjectNull();
        
    }
    
    U4DRender3DModel::~U4DRender3DModel(){
        
        [uniformBoneBuffer release];
        [nullSamplerDescriptor release];
        [shadowPropertiesBuffer release];
        
        uniformBoneBuffer=nil;
        nullSamplerDescriptor=nil;
        shadowTexture=nil;
        shadowPropertiesBuffer=nil;
    }
    
    U4DDualQuaternion U4DRender3DModel::getEntitySpace(){
        
        return u4dObject->getAbsoluteSpace();
        
    }
    
    U4DDualQuaternion U4DRender3DModel::getEntityLocalSpace(){
        
        return u4dObject->getLocalSpace();
        
    }
    
    U4DVector3n U4DRender3DModel::getEntityAbsolutePosition(){
        
        
        return u4dObject->getAbsolutePosition();
        
    }
    
    U4DVector3n U4DRender3DModel::getEntityLocalPosition(){
        
        return u4dObject->getLocalPosition();
        
    }

    
    void U4DRender3DModel::initMTLRenderLibrary(){
        
        mtlLibrary=[mtlDevice newDefaultLibrary];
        
        std::string vertexShaderName=u4dObject->getVertexShader();
        std::string fragmentShaderName=u4dObject->getFragmentShader();
        
        vertexProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:vertexShaderName.c_str()]];
        fragmentProgram=[mtlLibrary newFunctionWithName:[NSString stringWithUTF8String:fragmentShaderName.c_str()]];
        
    }
    
    void U4DRender3DModel::initMTLRenderPipeline(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        
        mtlRenderPipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        mtlRenderPipelineDescriptor.fragmentFunction=fragmentProgram;
        mtlRenderPipelineDescriptor.colorAttachments[0].pixelFormat=director->getMTLView().colorPixelFormat;
        mtlRenderPipelineDescriptor.depthAttachmentPixelFormat=director->getMTLView().depthStencilPixelFormat;
        
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
        
        
        mtlRenderPipelineDescriptor.vertexDescriptor=vertexDesc;
        mtlRenderPipelineDescriptor.vertexFunction=vertexProgram;
        
        
        depthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
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
    
    bool U4DRender3DModel::loadMTLBuffer(){
        
        //Align the attribute data
        alignedAttributeData();
        
        if (attributeAlignedContainer.size()==0) {
            
            eligibleToRender=false;
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: No attribute data (vertices, normals, etc) was found for the model %s. Make sure you exported all the model's data", u4dObject->getName().c_str());
            
            
            return false;
        }
        
        attributeBuffer=[mtlDevice newBufferWithBytes:&attributeAlignedContainer[0] length:sizeof(AttributeAlignedModelData)*attributeAlignedContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        //create the uniform
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
        
        uniformModelRenderFlagsBuffer=[mtlDevice newBufferWithLength:sizeof(UniformModelRenderFlags) options:MTLResourceStorageModeShared];
        
        uniformBoneBuffer=[mtlDevice newBufferWithLength:sizeof(UniformBoneSpace) options:MTLResourceStorageModeShared];
        
        lightPositionUniform=[mtlDevice newBufferWithLength:sizeof(vector_float4) options:MTLResourceStorageModeShared];
        
        shadowPropertiesBuffer=[mtlDevice newBufferWithLength:sizeof(UniformModelShadowProperties) options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRender3DModel::loadMTLTexture(){
        
        if (!u4dObject->textureInformation.texture0.empty() && u4dObject->bodyCoordinates.uVContainer.size()!=0){
            
            if (rawImageData.size()>0) {
                
                createTextureObject();
                
                createSamplerObject();
                
                u4dObject->setHasTexture(true);
                
            }else{
                U4DLogger *logger=U4DLogger::sharedInstance();
                
                logger->log("ERROR: No data found for the Image Texture");
            }
            
            //after loading the image, clear the vector holding the image in CPU
            
            clearRawImageData();
        }
        
    }
    
    void U4DRender3DModel::loadMTLAdditionalInformation(){
        
        //check if there is normal map data to load
            
        loadMTLNormalMapTexture();
        
        loadMTLMaterialInformation();
        
        loadMTLLightColorInformation();
    
    }
    
    void U4DRender3DModel::loadMTLLightColorInformation(){
        
        lightColorUniform=[mtlDevice newBufferWithLength:sizeof(UniformLightColor) options:MTLResourceStorageModeShared];
        
        U4DLights *light=U4DLights::sharedInstance();
        
        UniformLightColor uniformLightColor;
        
        U4DVector3n diffuseColor=light->getDiffuseColor();
        U4DVector3n specularColor=light->getSpecularColor();
        
        vector_float3 diffuseColorSIMD=convertToSIMD(diffuseColor);
        vector_float3 specularColorSIMD=convertToSIMD(specularColor);
        
        uniformLightColor.diffuseColor=diffuseColorSIMD;
        uniformLightColor.specularColor=specularColorSIMD;
        
        memcpy(lightColorUniform.contents, (void*)&uniformLightColor, sizeof(UniformLightColor));
        
    }
    
    void U4DRender3DModel::loadMTLMaterialInformation(){
        
        //create the uniform
        uniformMaterialBuffer=[mtlDevice newBufferWithLength:sizeof(UniformModelMaterial) options:MTLResourceStorageModeShared];
        
        
        if (u4dObject->materialInformation.materialIndexColorContainer.size()!=0) {
            
            UniformModelMaterial uniformModelMaterial;
            
            for(int i=0;i<u4dObject->materialInformation.diffuseMaterialColorContainer.size();i++){
                
                U4DVector4n color;
                color.x=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[0];
                color.y=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[1];
                color.z=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[2];
                color.w=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[3];
                
                vector_float4 colorSIMD=convertToSIMD(color);
                
                uniformModelMaterial.diffuseMaterialColor[i]=colorSIMD;
                
            }
            
            for(int i=0;i<u4dObject->materialInformation.specularMaterialColorContainer.size();i++){
                
                U4DVector4n color;
                color.x=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[0];
                color.y=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[1];
                color.z=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[2];
                color.w=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[3];
                
                vector_float4 colorSIMD=convertToSIMD(color);
                
                uniformModelMaterial.specularMaterialColor[i]=colorSIMD;
                
            }
            
            for(int i=0;i<u4dObject->materialInformation.diffuseMaterialIntensityContainer.size();i++){
                
                float intensity=u4dObject->materialInformation.diffuseMaterialIntensityContainer.at(i);
                
                uniformModelMaterial.diffuseMaterialIntensity[i]=intensity;
                
            }
            
            for(int i=0;i<u4dObject->materialInformation.specularMaterialIntensityContainer.size();i++){
                
                float intensity=u4dObject->materialInformation.specularMaterialIntensityContainer.at(i);
                
                uniformModelMaterial.specularMaterialIntensity[i]=intensity;
                
            }
            
            for(int i=0;i<u4dObject->materialInformation.specularMaterialHardnessContainer.size();i++){
                
                float hardness=u4dObject->materialInformation.specularMaterialHardnessContainer.at(i);
                
                uniformModelMaterial.specularMaterialHardness[i]=hardness;
                
            }
            
            memcpy(uniformMaterialBuffer.contents, (void*)&uniformModelMaterial, sizeof(UniformModelMaterial));
        
            
        }else{
            
            U4DLogger *logger=U4DLogger::sharedInstance();
            
            logger->log("ERROR: The model doesn't have any color material information. Make sure to add this information.");
            
        }
        
        
        
        
    }
    
    void U4DRender3DModel::loadMTLNormalMapTexture(){
        
        U4DResourceLoader *resourceLoader=U4DResourceLoader::sharedInstance();
        
        if (!u4dObject->textureInformation.normalBumpTexture.empty() && u4dObject->bodyCoordinates.tangentContainer.size()!=0){
            
            resourceLoader->loadNormalMap(u4dObject, u4dObject->textureInformation.normalBumpTexture);
            
            if (rawImageData.size()>0) {
                
                createNormalMapTextureObject();
                
                createNormalMapSamplerObject();
                
                u4dObject->setHasNormalMap(true);
            }else{
                U4DLogger *logger=U4DLogger::sharedInstance();
                
                logger->log("ERROR: No data found for the Image Normal Map Texture");
            }
            
            //after loading the image, clear the vector holding the image in CPU
            
            clearRawImageData();

        }
        
    }
    
    void U4DRender3DModel::updateBoneSpaceUniforms(){
        
        UniformBoneSpace uniformBoneSpace;
        
        for(int i=0;i<u4dObject->armatureBoneMatrix.size();i++){
            
            U4DMatrix4n boneSpace=u4dObject->armatureBoneMatrix.at(i);
            
            uniformBoneSpace.boneSpace[i]=convertToSIMD(boneSpace);
            
        }
        
        memcpy(uniformBoneBuffer.contents, (void*)&uniformBoneSpace, sizeof(UniformBoneSpace));
        
    }
    
    void U4DRender3DModel::updateShadowProperties(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        UniformModelShadowProperties shadowProperties;
        
        shadowProperties.biasDepth=director->getShadowBiasDepth();
        
        memcpy(shadowPropertiesBuffer.contents, (void*)&shadowProperties, sizeof(UniformModelShadowProperties));
    }
    
    void U4DRender3DModel::updateSpaceUniforms(){
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DLights *light=U4DLights::sharedInstance();
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
        
        U4DMatrix3n normalSpace=modelWorldViewSpace.extract3x3Matrix();
        
        normalSpace.invert();
        
        normalSpace=normalSpace.transpose();
        
        //get the light position in view space
        U4DVector3n lightPos=light->getAbsolutePosition();
        
        U4DVector4n lightPosition(lightPos.x, lightPos.y, lightPos.z, 1.0);
        
        //Conver to SIMD
        matrix_float4x4 modelSpaceSIMD=convertToSIMD(modelSpace);
        matrix_float4x4 worldModelSpaceSIMD=convertToSIMD(worldSpace);
        matrix_float4x4 viewWorldModelSpaceSIMD=convertToSIMD(modelWorldViewSpace);
        matrix_float4x4 viewSpaceSIMD=convertToSIMD(viewSpace);
        matrix_float4x4 mvpSpaceSIMD=convertToSIMD(mvpSpace);
        
        matrix_float3x3 normalSpaceSIMD=convertToSIMD(normalSpace);
        vector_float4 lightPositionSIMD=convertToSIMD(lightPosition);
        
        matrix_float4x4 lightShadowProjectionSpaceSIMD=convertToSIMD(lightShadowProjectionSpace);
        
        UniformSpace uniformSpace;
        uniformSpace.modelSpace=modelSpaceSIMD;
        uniformSpace.viewSpace=viewSpaceSIMD;
        uniformSpace.modelViewSpace=viewWorldModelSpaceSIMD;
        uniformSpace.modelViewProjectionSpace=mvpSpaceSIMD;
        uniformSpace.normalSpace=normalSpaceSIMD;
        uniformSpace.lightShadowProjectionSpace=lightShadowProjectionSpaceSIMD;
        
        
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        memcpy(lightPositionUniform.contents, (void*)&lightPositionSIMD, sizeof(vector_float4));
        
        
    }
    
    void U4DRender3DModel::updateModelRenderFlags(){
        
        //update the rendering flags
        UniformModelRenderFlags modelFlags;
        modelFlags.enableShadows=u4dObject->getEnableShadow();
        modelFlags.enableNormalMap=u4dObject->getEnableNormalMap();
        modelFlags.hasTexture=u4dObject->getHasTexture();
        modelFlags.hasArmature=u4dObject->getHasArmature();
        
        memcpy(uniformModelRenderFlagsBuffer.contents, (void*)&modelFlags, sizeof(UniformModelRenderFlags));
        
    }
    
    void U4DRender3DModel::updateShadowSpaceUniforms(){
        
        U4DLights *light=U4DLights::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=getEntitySpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n lightSpace=light->getLocalSpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n orthogonalProjection=director->getOrthographicShadowSpace();
                
        //Transfom the Model-View Space into the Projection space
        lightShadowProjectionSpace=orthogonalProjection*lightSpace;
        
        //Convert to SIMD
        matrix_float4x4 lightShadowProjectionSpaceSIMD=convertToSIMD(lightShadowProjectionSpace);
        
        matrix_float4x4 modelMatrixSIMD=convertToSIMD(modelSpace);
        
        
        UniformSpace uniformSpace;
        uniformSpace.modelSpace=modelMatrixSIMD;
        uniformSpace.lightShadowProjectionSpace=lightShadowProjectionSpaceSIMD;
        memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
    }
    
    void U4DRender3DModel::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true && isWithinFrustum==true) {
            
            updateSpaceUniforms();
            updateModelRenderFlags();
            updateBoneSpaceUniforms();
            updateShadowProperties();
            
            //update the global uniforms
            updateGlobalDataUniforms();
            
            //encode the pipeline
            [uRenderEncoder setRenderPipelineState:mtlRenderPipelineState];
            
            [uRenderEncoder setDepthStencilState:depthStencilState];
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            [uRenderEncoder setVertexBuffer:lightPositionUniform offset:0 atIndex:2];
            
            [uRenderEncoder setVertexBuffer:uniformModelRenderFlagsBuffer offset:0 atIndex:3];
            
            [uRenderEncoder setVertexBuffer:uniformBoneBuffer offset:0 atIndex:4];
            
            [uRenderEncoder setVertexBuffer:globalDataUniform offset:0 atIndex:5];
            
            //set texture in fragment
            [uRenderEncoder setFragmentTexture:textureObject atIndex:0];
            //set the samplers
            [uRenderEncoder setFragmentSamplerState:samplerStateObject atIndex:0];
            
            //set the shadow texture
            [uRenderEncoder setFragmentTexture:shadowTexture atIndex:1];
            
            
            //set data used in fragment
            [uRenderEncoder setFragmentBuffer:uniformModelRenderFlagsBuffer offset:0 atIndex:1];
            [uRenderEncoder setFragmentBuffer:uniformMaterialBuffer offset:0 atIndex:2];
            [uRenderEncoder setFragmentBuffer:lightColorUniform offset:0 atIndex:3];
            [uRenderEncoder setFragmentBuffer:shadowPropertiesBuffer offset:0 atIndex:4];
            [uRenderEncoder setFragmentBuffer:globalDataUniform offset:0 atIndex:5];
            
            [uRenderEncoder setFragmentTexture:normalMapTextureObject atIndex:2];
            [uRenderEncoder setFragmentSamplerState:samplerNormalMapStateObject atIndex:1];
            
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }
    
    void U4DRender3DModel::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
     
        if (eligibleToRender==true) {
            
            //set the shadow texture
            
            shadowTexture=uShadowTexture;
            
            updateShadowSpaceUniforms();
            updateModelRenderFlags();
            updateBoneSpaceUniforms();
            
            [uRenderShadowEncoder setDepthBias: 0.01 slopeScale: 1.0f clamp: 0.01];
            
            [uRenderShadowEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:0];
            
            [uRenderShadowEncoder setVertexBuffer:uniformSpaceBuffer offset:0 atIndex:1];
            
            [uRenderShadowEncoder setVertexBuffer:uniformModelRenderFlagsBuffer offset:0 atIndex:2];
            
            [uRenderShadowEncoder setVertexBuffer:uniformBoneBuffer offset:0 atIndex:3];
            
            [uRenderShadowEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
    }
    
    void U4DRender3DModel::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor;
        nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null normal texture object
        normalMapTextureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null shadow texture object
        shadowTexture=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null texture sampler object
        nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        samplerNormalMapStateObject=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
        
    }
    
    void U4DRender3DModel::clearModelAttributeData(){
        
        //clear the attribute data contatiner
        attributeAlignedContainer.clear();
        
        u4dObject->bodyCoordinates.verticesContainer.clear();
        u4dObject->bodyCoordinates.normalContainer.clear();
        u4dObject->bodyCoordinates.uVContainer.clear();
        u4dObject->bodyCoordinates.tangentContainer.clear();
        u4dObject->materialInformation.materialIndexColorContainer.clear();
        u4dObject->bodyCoordinates.vertexWeightsContainer.clear();
        u4dObject->bodyCoordinates.boneIndicesContainer.clear();
        
    }
    
    void U4DRender3DModel::alignedAttributeData(){
        
        bool alignUVContainer=false;
        bool alignTangentContainer=false;
        bool alignMaterialContainer=false;
        bool alignArmature=false;
        
        if (u4dObject->bodyCoordinates.uVContainer.size()>0) alignUVContainer=true;
        if (u4dObject->bodyCoordinates.tangentContainer.size()>0) alignTangentContainer=true;
        if (u4dObject->materialInformation.materialIndexColorContainer.size()>0) alignMaterialContainer=true;
        
        if (u4dObject->getHasArmature()==true) {
            if((u4dObject->bodyCoordinates.vertexWeightsContainer.size()==u4dObject->bodyCoordinates.verticesContainer.size())&&(u4dObject->bodyCoordinates.vertexWeightsContainer.size()>0)&&(u4dObject->bodyCoordinates.verticesContainer.size()>0)) {
                
                alignArmature=true;
            
            }else{
                
                U4DLogger *logger=U4DLogger::sharedInstance();
                logger->log("ERROR: Number of vertices does not macth number of vertex weights or vertex weighs container size is zero. Make sure your model's armature is correct");
                
            }
        
        }
        
        //create the structure that contains the align data
        AttributeAlignedModelData attributeAlignedData;
        
        //initialize the container to a temp container
        std::vector<AttributeAlignedModelData> attributeAlignedContainerTemp(u4dObject->bodyCoordinates.getVerticesDataFromContainer().size(),attributeAlignedData);
        
        //copy the temp containter to the actual container. I wanted to initialize the container directly without using the temp container
        //but it kept giving me errors. I think there is a better way to do this.
        attributeAlignedContainer=attributeAlignedContainerTemp;
        
        for(int i=0; i<attributeAlignedContainer.size();i++){
            
            //align vertex data
            U4DVector3n vertexData=u4dObject->bodyCoordinates.verticesContainer.at(i);
            attributeAlignedContainer.at(i).position.xyz=convertToSIMD(vertexData);
            attributeAlignedContainer.at(i).position.w=1.0;
            
            //align normal data
            U4DVector3n normalData=u4dObject->bodyCoordinates.normalContainer.at(i);
            attributeAlignedContainer.at(i).normal.xyz=convertToSIMD(normalData);
            attributeAlignedContainer.at(i).normal.w=1.0;
            
            //align uv data
            if (alignUVContainer) {
                
                U4DVector2n uvData=u4dObject->bodyCoordinates.uVContainer.at(i);
                
                attributeAlignedContainer.at(i).uv.xy=convertToSIMD(uvData);
                attributeAlignedContainer.at(i).uv.z=0.0;
                attributeAlignedContainer.at(i).uv.w=0.0;
                
            }
            
            //align tangent coord data for normal maps
            if (alignTangentContainer) {
                
                U4DVector4n tangentData=u4dObject->bodyCoordinates.tangentContainer.at(i);
                
                attributeAlignedContainer.at(i).tangent.xyzw=convertToSIMD(tangentData);
                
            }
            
            //align material container
            if (alignMaterialContainer) {
                
                attributeAlignedContainer.at(i).materialIndex.x=u4dObject->materialInformation.materialIndexColorContainer.at(i);
                
            }
            
            //align armature data
            if(alignArmature){
                
                U4DVector4n vertexWeightData=u4dObject->bodyCoordinates.vertexWeightsContainer.at(i);
                
                attributeAlignedContainer.at(i).vertexWeight.xyzw=convertToSIMD(vertexWeightData);
                
                U4DVector4n boneIndexData=u4dObject->bodyCoordinates.boneIndicesContainer.at(i);
                
                attributeAlignedContainer.at(i).boneIndex.xyzw=convertToSIMD(boneIndexData);
                
            }
            
        }
        
    }


    void U4DRender3DModel::setRawImageData(std::vector<unsigned char> uRawImageData){
        
        rawImageData=uRawImageData;
        
    }

    void U4DRender3DModel::setImageWidth(unsigned int uImageWidth){
        
        imageWidth=uImageWidth;
        
    }

    void U4DRender3DModel::setImageHeight(unsigned int uImageHeight){
        
        imageHeight=uImageHeight;
    }


}

