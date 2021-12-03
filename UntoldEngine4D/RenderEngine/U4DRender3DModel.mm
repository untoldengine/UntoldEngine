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
#include "U4DMaterialData.h"
#include "U4DColorData.h"
#include "U4DResourceLoader.h"
#include "U4DNumerical.h"
#include "CommonProtocols.h"

namespace U4DEngine {

U4DRender3DModel::U4DRender3DModel(U4DModel *uU4DModel):uniformMaterialBuffer(nil),uniformBoneBuffer(nil),nullSamplerDescriptor(nil),uniformModelRenderFlagsBuffer(nil),normalMapTextureObject(nil),samplerNormalMapStateObject(nil),uniformModelShaderParametersBuffer(nil),normalSamplerDescriptor(nil),textureObject{nil,nil,nil,nil},samplerStateObject{nil,nil,nil,nil},samplerDescriptor{nullptr,nullptr,nullptr,nullptr}{
        
        u4dObject=uU4DModel;
        
        //It seems we do need to init the texture objects with a null descriptor
        initTextureSamplerObjectNull();
        
    }
    
    U4DRender3DModel::~U4DRender3DModel(){
        
        [uniformBoneBuffer release];
        [nullSamplerDescriptor release];
        
        uniformBoneBuffer=nil;
        nullSamplerDescriptor=nil;
        
        uniformModelRenderFlagsBuffer=nil;
        normalMapTextureObject=nil;
        samplerNormalMapStateObject=nil;
        
        uniformModelShaderParametersBuffer=nil;
        
        for(int i=0;i<4;i++){
            //It seems that setting the Purgeable state to empty, causes metal to ignore buffer dependencies. Had to comment this section out since it is causing the engine to crash whenever I'm deleting an entity.
            //[textureObject[i] setPurgeableState:MTLPurgeableStateEmpty];
            [textureObject[i] release];
            
            [samplerStateObject[i] release];
            
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
        NSUInteger dynamicUniformSpaceBuffer=U4DEngine::kAlignedUniformSpaceSize*U4DEngine::kMaxBuffersInFlight;
        
        NSUInteger dynamicUniformBoneBuffer=U4DEngine::kAlignedUniformBoneSize*U4DEngine::kMaxBuffersInFlight;
        
        uniformSpaceBuffer=[mtlDevice newBufferWithLength:dynamicUniformSpaceBuffer options:MTLResourceStorageModeShared];
        
        uniformModelRenderFlagsBuffer=[mtlDevice newBufferWithLength:sizeof(UniformModelRenderFlags) options:MTLResourceStorageModeShared];
        
        uniformBoneBuffer=[mtlDevice newBufferWithLength:dynamicUniformBoneBuffer options:MTLResourceStorageModeShared];
        
        //load the index into the buffer
        indicesBuffer=[mtlDevice newBufferWithBytes:&u4dObject->bodyCoordinates.indexContainer[0] length:sizeof(int)*3*u4dObject->bodyCoordinates.indexContainer.size() options:MTLResourceOptionCPUCacheModeDefault];
        
        eligibleToRender=true;
        
        return true;
    }
    
    void U4DRender3DModel::loadMTLTexture(){
        
        if(u4dObject->bodyCoordinates.uVContainer.size()!=0){
            
            //load texture0
            if (!u4dObject->textureInformation.texture0.empty()){
                
                if (createTextureAndSamplerObjects(textureObject[0], samplerStateObject[0], samplerDescriptor[0], u4dObject->textureInformation.texture0.c_str())) {
                    
                    u4dObject->setHasTexture(true);
                    
                }else{
                    
                    U4DLogger *logger=U4DLogger::sharedInstance();
                    
                    logger->log("ERROR: No data found for the Image Texture %s",u4dObject->textureInformation.texture0.c_str());
                    
                }
                
            }
            
            //load texture1
            if (!u4dObject->textureInformation.texture1.empty()){
                    
                if (createTextureAndSamplerObjects(textureObject[1], samplerStateObject[1], samplerDescriptor[1], u4dObject->textureInformation.texture1.c_str())) {
                    
                    //set any flags here
                    
                }else{
                    
                    U4DLogger *logger=U4DLogger::sharedInstance();
                    
                    logger->log("ERROR: No data found for the Image Texture %s", u4dObject->textureInformation.texture1.c_str());
                    
                }
                
            }
            
        }
        
        
    }
    
    void U4DRender3DModel::loadMTLAdditionalInformation(){
        
        //check if there is normal map data to load
            
        loadMTLNormalMapTexture();
        
        loadMTLMaterialInformation();
        
        //load user-defined parameters uniform
        uniformModelShaderParametersBuffer=[mtlDevice newBufferWithLength:sizeof(UniformModelShaderProperty) options:MTLResourceStorageModeShared];
    
    }
    
    
    
    void U4DRender3DModel::loadMTLMaterialInformation(){
        
        //create the uniform
        uniformMaterialBuffer=[mtlDevice newBufferWithLength:sizeof(UniformModelMaterial) options:MTLResourceStorageModeShared];
        
        U4DNumerical numerical;
        
        if (u4dObject->materialInformation.materialIndexColorContainer.size()!=0) {
            
            UniformModelMaterial uniformModelMaterial;
            
            for(int i=0;i<u4dObject->materialInformation.diffuseMaterialColorContainer.size();i++){
                
                U4DVector4n color;
                color.x=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[0];
                color.y=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[1];
                color.z=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[2];
                color.w=u4dObject->materialInformation.diffuseMaterialColorContainer.at(i).colorData[3];
                
                vector_float4 colorSIMD=numerical.convertToSIMD(color);
                
                uniformModelMaterial.diffuseMaterialColor[i]=colorSIMD;
                
            }
            
            for(int i=0;i<u4dObject->materialInformation.specularMaterialColorContainer.size();i++){
                
                U4DVector4n color;
                color.x=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[0];
                color.y=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[1];
                color.z=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[2];
                color.w=u4dObject->materialInformation.specularMaterialColorContainer.at(i).colorData[3];
                
                vector_float4 colorSIMD=numerical.convertToSIMD(color);
                
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

    void U4DRender3DModel::createNormalMapTextureObject(){
        
        //Create the texture descriptor
        
        MTLTextureDescriptor *normalMapTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:imageWidth height:imageHeight mipmapped:NO];
        
        //Create the normal texture object
        normalMapTextureObject=[mtlDevice newTextureWithDescriptor:normalMapTextureDescriptor];
        
        //Copy the normal map raw image data into the texture object
        
        MTLRegion region=MTLRegionMake2D(0, 0, imageWidth, imageHeight);
        
        [normalMapTextureObject replaceRegion:region mipmapLevel:0 withBytes:&rawImageData[0] bytesPerRow:4*imageWidth];
        
        
    }

    void U4DRender3DModel::createNormalMapSamplerObject(){
        
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
    
    void U4DRender3DModel::updateBoneSpaceUniforms(){
        
        boneTripleBuffer.index = (boneTripleBuffer.index + 1) % U4DEngine::kMaxBuffersInFlight;
        
        boneTripleBuffer.offset = U4DEngine::kAlignedUniformBoneSize * boneTripleBuffer.index;
        
        boneTripleBuffer.address = ((uint8_t*)uniformBoneBuffer.contents) + boneTripleBuffer.offset;
        
        
        UniformBoneSpace *uniformBoneSpace=(UniformBoneSpace*)boneTripleBuffer.address;
        
        U4DNumerical numerical;
        
        for(int i=0;i<u4dObject->armatureBoneMatrix.size();i++){
            
            U4DMatrix4n boneSpace=u4dObject->armatureBoneMatrix.at(i);
            
            uniformBoneSpace->boneSpace[i]=numerical.convertToSIMD(boneSpace);
            
        }
        
        //memcpy(uniformBoneBuffer.contents, (void*)&uniformBoneSpace, sizeof(UniformBoneSpace));
        
    }
    

    void U4DRender3DModel::updateSpaceUniforms(){
        
        spaceTripleBuffer.index = (spaceTripleBuffer.index + 1) % U4DEngine::kMaxBuffersInFlight;
        
        spaceTripleBuffer.offset = U4DEngine::kAlignedUniformSpaceSize * spaceTripleBuffer.index;
        
        spaceTripleBuffer.address = ((uint8_t*)uniformSpaceBuffer.contents) + spaceTripleBuffer.offset;
        
        U4DCamera *camera=U4DCamera::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        U4DMatrix4n modelSpace=u4dObject->getAbsoluteSpace().transformDualQuaternionToMatrix4n();
        
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
    
        
        //Conver to SIMD
        U4DNumerical numerical;
        
        matrix_float4x4 modelSpaceSIMD=numerical.convertToSIMD(modelSpace);
        //matrix_float4x4 worldModelSpaceSIMD=numerical.convertToSIMD(worldSpace);
        matrix_float4x4 viewWorldModelSpaceSIMD=numerical.convertToSIMD(modelWorldViewSpace);
        matrix_float4x4 viewSpaceSIMD=numerical.convertToSIMD(viewSpace);
        matrix_float4x4 mvpSpaceSIMD=numerical.convertToSIMD(mvpSpace);
        
        matrix_float3x3 normalSpaceSIMD=numerical.convertToSIMD(normalSpace);

        
        UniformSpace *uniformSpace=(UniformSpace*)spaceTripleBuffer.address;
        
        uniformSpace->modelSpace=modelSpaceSIMD;
        uniformSpace->viewSpace=viewSpaceSIMD;
        uniformSpace->modelViewSpace=viewWorldModelSpaceSIMD;
        uniformSpace->modelViewProjectionSpace=mvpSpaceSIMD;
        uniformSpace->normalSpace=normalSpaceSIMD;
        
        
        //memcpy(uniformSpaceBuffer.contents, (void*)&uniformSpace, sizeof(UniformSpace));
        
        
    }
    
    void U4DRender3DModel::updateModelRenderFlags(){
        
        //update the rendering flags
        UniformModelRenderFlags modelFlags;
        modelFlags.enableNormalMap=u4dObject->getEnableNormalMap();
        modelFlags.hasTexture=u4dObject->getHasTexture();
        modelFlags.hasArmature=u4dObject->getHasArmature();
        
        memcpy(uniformModelRenderFlagsBuffer.contents, (void*)&modelFlags, sizeof(UniformModelRenderFlags));
        
    }
    
    

    void U4DRender3DModel::updateAllUniforms(){
        
        updateSpaceUniforms();
        updateModelRenderFlags();
        updateBoneSpaceUniforms();
        updateModelShaderParametersUniform();
        
        
    }
    
    void U4DRender3DModel::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        if (eligibleToRender==true) {
            
            //encode the buffers
            [uRenderEncoder setVertexBuffer:attributeBuffer offset:0 atIndex:viAttributeBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformSpaceBuffer offset:spaceTripleBuffer.offset atIndex:viSpaceBuffer];
            
            
            [uRenderEncoder setVertexBuffer:uniformModelRenderFlagsBuffer offset:0 atIndex:viModelRenderFlagBuffer];
            
            [uRenderEncoder setVertexBuffer:uniformBoneBuffer offset:boneTripleBuffer.offset atIndex:viBoneBuffer];
            
            
            [uRenderEncoder setVertexBuffer:uniformModelShaderParametersBuffer offset:0 atIndex:viModelShaderPropertyBuffer];
            
            //set texture in fragment
            [uRenderEncoder setFragmentTexture:textureObject[0] atIndex:fiTexture0];
            //set the samplers
            [uRenderEncoder setFragmentSamplerState:samplerStateObject[0] atIndex:fiSampler0];
            
            
            //set data used in fragment
            [uRenderEncoder setFragmentBuffer:uniformModelRenderFlagsBuffer offset:0 atIndex:fiModelRenderFlagsBuffer];
            [uRenderEncoder setFragmentBuffer:uniformMaterialBuffer offset:0 atIndex:fiMaterialBuffer];
            
            [uRenderEncoder setFragmentBuffer:uniformModelShaderParametersBuffer offset:0 atIndex:fiModelShaderPropertyBuffer];
            
            //set normal texture
            [uRenderEncoder setFragmentTexture:normalMapTextureObject atIndex:fiNormalTexture];
            [uRenderEncoder setFragmentSamplerState:samplerNormalMapStateObject atIndex:fiNormalSampler];
            
            //texture1
            [uRenderEncoder setFragmentTexture:textureObject[1] atIndex:fiTexture1];
            //set the samplers
            [uRenderEncoder setFragmentSamplerState:samplerStateObject[1] atIndex:fiSampler1];
            
            //set offscreen texture
            //[uRenderEncoder setFragmentTexture:offscreenTexture atIndex:4];
            
            
            //set the draw command
            [uRenderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:[indicesBuffer length]/sizeof(int) indexType:MTLIndexTypeUInt32 indexBuffer:indicesBuffer indexBufferOffset:0];
            
        }
        
        
    }
    
    void U4DRender3DModel::initTextureSamplerObjectNull(){
        
        MTLTextureDescriptor *nullDescriptor;
        nullDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
        
        //Create the null texture object
        textureObject[0]=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        //Create the null normal texture object
        normalMapTextureObject=[mtlDevice newTextureWithDescriptor:nullDescriptor];
        
        
        
        //Create the null texture sampler object
        nullSamplerDescriptor=[[MTLSamplerDescriptor alloc] init];
        
        samplerStateObject[0]=[mtlDevice newSamplerStateWithDescriptor:nullSamplerDescriptor];
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
        
        U4DNumerical numerical;
        
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
            attributeAlignedContainer.at(i).position.xyz=numerical.convertToSIMD(vertexData);
            attributeAlignedContainer.at(i).position.w=1.0;
            
            //align normal data
            U4DVector3n normalData=u4dObject->bodyCoordinates.normalContainer.at(i);
            attributeAlignedContainer.at(i).normal.xyz=numerical.convertToSIMD(normalData);
            attributeAlignedContainer.at(i).normal.w=1.0;
            
            //align uv data
            if (alignUVContainer) {
                
                U4DVector2n uvData=u4dObject->bodyCoordinates.uVContainer.at(i);
                
                attributeAlignedContainer.at(i).uv.xy=numerical.convertToSIMD(uvData);
                attributeAlignedContainer.at(i).uv.z=0.0;
                attributeAlignedContainer.at(i).uv.w=0.0;
                
            }
            
            //align tangent coord data for normal maps
            if (alignTangentContainer) {
                
                U4DVector4n tangentData=u4dObject->bodyCoordinates.tangentContainer.at(i);
                
                attributeAlignedContainer.at(i).tangent.xyzw=numerical.convertToSIMD(tangentData);
                
            }
            
            //align material container
            if (alignMaterialContainer) {
                
                attributeAlignedContainer.at(i).materialIndex.x=u4dObject->materialInformation.materialIndexColorContainer.at(i);
                
            }
            
            //align armature data
            if(alignArmature){
                
                U4DVector4n vertexWeightData=u4dObject->bodyCoordinates.vertexWeightsContainer.at(i);
                
                attributeAlignedContainer.at(i).vertexWeight.xyzw=numerical.convertToSIMD(vertexWeightData);
                
                U4DVector4n boneIndexData=u4dObject->bodyCoordinates.boneIndicesContainer.at(i);
                
                attributeAlignedContainer.at(i).boneIndex.xyzw=numerical.convertToSIMD(boneIndexData);
                
            }
            
        }
        
    }


    void U4DRender3DModel::updateModelShaderParametersUniform(){
        
        U4DNumerical numerical;
        
        int sizeOfModelParameterVector=(int)u4dObject->getModelShaderParameterContainer().size();
        
        UniformModelShaderProperty uniformModelShaderProperty;
        
        for(int i=0;i<sizeOfModelParameterVector;i++){
        
            //load param1
            U4DVector4n shaderParameter=u4dObject->getModelShaderParameterContainer().at(i);
            
            vector_float4 shaderParameterSIMD=numerical.convertToSIMD(shaderParameter);
            
            uniformModelShaderProperty.shaderParameter[i]=shaderParameterSIMD;
            
        }
        
        memcpy(uniformModelShaderParametersBuffer.contents,(void*)&uniformModelShaderProperty, sizeof(UniformModelShaderProperty));
        
    }


}

