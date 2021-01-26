//
//  RenderManager.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 6/30/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderManager.h"
#include <simd/simd.h>
#include "U4DSceneManager.h"
#include "CommonProtocols.h"
#include "U4DDirector.h"
#include "U4DShaderProtocols.h"
#include "U4DDirectionalLight.h"
#include "U4DDirector.h"
#include "U4DNumerical.h"
#include "U4DRenderEntity.h"
#include "U4DPointLight.h"
#include "U4DModelPipeline.h"
#include "U4DShadowRenderPipeline.h"
#include "U4DImagePipeline.h"
#include "U4DOffscreenPipeline.h"
#include "U4DSkyboxPipeline.h"
#include "U4DParticlesPipeline.h"
#include "U4DShaderEntityPipeline.h"
#include "U4DGeometryPipeline.h"
#include "U4DWorldPipeline.h"
#include "U4DGBufferPipeline.h"
#include "U4DCompositionPipeline.h"

namespace U4DEngine {

    U4DRenderManager* U4DRenderManager::instance=0;
        
    U4DRenderManager* U4DRenderManager::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DRenderManager();
            
        }
        
        return instance;
    }

    U4DRenderManager::U4DRenderManager(){
        
    }
    
    U4DRenderManager::~U4DRenderManager(){

        
    }
 
    void U4DRenderManager::updateGlobalDataUniforms(){
        
        U4DNumerical numerical;
        
        U4DDirector *director=U4DDirector::sharedInstance();
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        U4DPointLight *pointLight=U4DPointLight::sharedInstance();
        
        U4DScene *scene=sceneManager->getCurrentScene();
        
        //get the resolution of the display
        U4DVector2n resolution(director->getDisplayWidth(),director->getDisplayHeight());
        
        vector_float2 resolutionSIMD=numerical.convertToSIMD(resolution);
        
        int numberOfPointLights=(int)pointLight->pointLightsContainer.size();
        
        
        UniformGlobalData uniformGlobalData;
        uniformGlobalData.time=scene->getGlobalTime(); //set the global time
        uniformGlobalData.resolution=resolutionSIMD; //set the display resolution
        uniformGlobalData.numberOfPointLights=numberOfPointLights; //set the number of points light
        
        
        memcpy(globalDataUniform.contents, (void*)&uniformGlobalData, sizeof(UniformGlobalData));
        
    }
        
    void U4DRenderManager::updateDirLightDataUniforms(){
        
        U4DDirectionalLight *light=U4DDirectionalLight::sharedInstance();
        U4DDirector *director=U4DDirector::sharedInstance();
        
        //get the light position in view space
        U4DVector3n lightPos=light->getAbsolutePosition();
        
        U4DVector4n lightPosition(lightPos.x, lightPos.y, lightPos.z, 1.0);
        
        //get the light color
        U4DVector3n diffuseColor=light->getDiffuseColor();
        U4DVector3n specularColor=light->getSpecularColor();
        
        //get the light orthogonal shadow projection
        U4DMatrix4n lightSpace=light->getLocalSpace().transformDualQuaternionToMatrix4n();
        
        U4DMatrix4n orthogonalProjection=director->getOrthographicShadowSpace();
                
        //Transfom the Model-View Space into the Projection space
        U4DMatrix4n lightShadowProjectionSpace=orthogonalProjection*lightSpace;
        
        //Convert to SIMD
        U4DNumerical numerical;
        
        matrix_float4x4 lightShadowProjectionSpaceSIMD=numerical.convertToSIMD(lightShadowProjectionSpace);
        vector_float4 lightPositionSIMD=numerical.convertToSIMD(lightPosition);
        vector_float3 diffuseColorSIMD=numerical.convertToSIMD(diffuseColor);
        vector_float3 specularColorSIMD=numerical.convertToSIMD(specularColor);
        
        UniformDirectionalLightProperties lightProperties;
        
        lightProperties.lightShadowProjectionSpace=lightShadowProjectionSpaceSIMD;
        lightProperties.lightPosition=lightPositionSIMD;
        lightProperties.diffuseColor=diffuseColorSIMD;
        lightProperties.specularColor=specularColorSIMD;
        
        memcpy(directionalLightPropertiesUniform.contents, (void*)&lightProperties, sizeof(UniformDirectionalLightProperties));
        
    }

    void U4DRenderManager::updatePointLightDataUniforms(){
        
        U4DPointLight *pointLights=U4DPointLight::sharedInstance();
        int numberOfPointLights=(int)pointLights->pointLightsContainer.size();
        UniformPointLightProperties uniformPointLightProperty[numberOfPointLights];
            
            for(int i=0;i<numberOfPointLights;i++){
                
                //load position
                U4DVector3n pos=pointLights->pointLightsContainer.at(i).position;
                U4DVector4n position(pos.x,pos.y,pos.z,1.0);
                U4DVector3n diffuse=pointLights->pointLightsContainer.at(i).diffuseColor;
                float constantAtten=pointLights->pointLightsContainer.at(i).constantAttenuation;
                float linearAtten=pointLights->pointLightsContainer.at(i).linearAttenuation;
                float expAtten=pointLights->pointLightsContainer.at(i).expAttenuation;
                //Convert to SIMD
                U4DNumerical numerical;
                
                vector_float4 positionSIMD=numerical.convertToSIMD(position);
                vector_float3 diffuseSIMD=numerical.convertToSIMD(diffuse);
                
                uniformPointLightProperty[i].lightPosition=positionSIMD;
                uniformPointLightProperty[i].diffuseColor=diffuseSIMD;
                uniformPointLightProperty[i].constantAttenuation=constantAtten;
                uniformPointLightProperty[i].linearAttenuation=linearAtten;
                uniformPointLightProperty[i].expAttenuation=expAtten;
                
            }
            
        memcpy(pointLightsPropertiesUniform.contents,(void*)&uniformPointLightProperty, sizeof(UniformPointLightProperties)*numberOfPointLights);
        
    }

    void U4DRenderManager::initRenderPipelines(id <MTLDevice> uMTLDevice){
        
        //init global data buffer
        globalDataUniform=[uMTLDevice newBufferWithLength:sizeof(UniformGlobalData) options:MTLResourceStorageModeShared];
        
        //init dir light buffer
        directionalLightPropertiesUniform=[uMTLDevice newBufferWithLength:sizeof(UniformDirectionalLightProperties) options:MTLResourceStorageModeShared];
        
        //init point light buffer
        pointLightsPropertiesUniform=[uMTLDevice newBufferWithLength:sizeof(UniformPointLightProperties)*U4DEngine::maxNumberOfLights options:MTLResourceStorageModeShared]; 
        
        U4DModelPipeline* modelPipeline=new U4DModelPipeline(uMTLDevice, "modelpipeline");
        modelPipeline->initRenderPass("vertexModelShader", "fragmentModelShader");

        U4DShadowRenderPipeline* shadowPipeline=new U4DShadowRenderPipeline(uMTLDevice,"shadowpipeline");
        shadowPipeline->initRenderPass("vertexShadowShader", " ");
        
        U4DImagePipeline* imagePipeline=new U4DImagePipeline(uMTLDevice,"imagepipeline");
        imagePipeline->initRenderPass("vertexImageShader","fragmentImageShader");
        
        U4DGeometryPipeline* geometryPipeline=new U4DGeometryPipeline(uMTLDevice,"geometrypipeline");
        geometryPipeline->initRenderPass("vertexGeometryShader", "fragmentGeometryShader"); 
        
        U4DOffscreenPipeline* offscreenPipeline=new U4DOffscreenPipeline(uMTLDevice,"offscreenpipeline");
        offscreenPipeline->initRenderPass("vertexOffscreenShader","fragmentOffscreenShader");
        
        U4DSkyboxPipeline* skyboxPipeline=new U4DSkyboxPipeline(uMTLDevice,"skyboxpipeline");
        skyboxPipeline->initRenderPass("vertexSkyboxShader", "fragmentSkyboxShader");
        
        U4DParticlesPipeline* particlePipeline=new U4DParticlesPipeline(uMTLDevice,"particlepipeline");
        particlePipeline->initRenderPass("vertexParticleSystemShader", "fragmentParticleSystemShader");
        
        U4DShaderEntityPipeline* checkboxPipeline=new U4DShaderEntityPipeline(uMTLDevice, "checkboxpipeline");
        checkboxPipeline->initRenderPass("vertexUICheckboxShader", "fragmentUICheckboxShader");
        
        U4DShaderEntityPipeline* sliderPipeline=new U4DShaderEntityPipeline(uMTLDevice, "sliderpipeline");
        sliderPipeline->initRenderPass("vertexUISliderShader", "fragmentUISliderShader");
        
        U4DShaderEntityPipeline* buttonPipeline=new U4DShaderEntityPipeline(uMTLDevice, "buttonpipeline");
        buttonPipeline->initRenderPass("vertexUIButtonShader", "fragmentUIButtonShader");
        
        U4DShaderEntityPipeline* joystickPipeline=new U4DShaderEntityPipeline(uMTLDevice, "joystickpipeline");
        joystickPipeline->initRenderPass("vertexUIJoystickShader", "fragmentUIJoystickShader");
        
        U4DWorldPipeline *worldPipeline=new U4DWorldPipeline(uMTLDevice,"worldpipeline");
        worldPipeline->initRenderPass("vertexWorldShader", "fragmentWorldShader");
        
        U4DGBufferPipeline *gBufferPipeline=new U4DGBufferPipeline(uMTLDevice,"gbufferpipeline");
        gBufferPipeline->initRenderPass("vertexGBufferShader","fragmentGBufferShader");
        
        U4DCompositionPipeline *compositionPipeline=new U4DCompositionPipeline(uMTLDevice,"compositionpipeline");
        compositionPipeline->initRenderPass("vertexCompShader","fragmentCompShader");
        
        renderingPipelineContainer.push_back(modelPipeline);
        renderingPipelineContainer.push_back(shadowPipeline);
        renderingPipelineContainer.push_back(geometryPipeline);
        renderingPipelineContainer.push_back(imagePipeline);
        renderingPipelineContainer.push_back(offscreenPipeline);
        renderingPipelineContainer.push_back(skyboxPipeline);
        renderingPipelineContainer.push_back(particlePipeline);
        renderingPipelineContainer.push_back(checkboxPipeline);
        renderingPipelineContainer.push_back(sliderPipeline);
        renderingPipelineContainer.push_back(buttonPipeline);
        renderingPipelineContainer.push_back(joystickPipeline);
        renderingPipelineContainer.push_back(worldPipeline);
        renderingPipelineContainer.push_back(gBufferPipeline);
        renderingPipelineContainer.push_back(compositionPipeline);
        
    }

    void U4DRenderManager::render(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        updateDirLightDataUniforms();
        updatePointLightDataUniforms();
        updateGlobalDataUniforms();
        
        U4DRenderPipelineInterface *shadowPipeline=searchPipeline("shadowpipeline");
        
        id <MTLRenderCommandEncoder> shadowRenderEncoder =
        [uCommandBuffer renderCommandEncoderWithDescriptor:shadowPipeline->mtlRenderPassDescriptor];
        
        [shadowRenderEncoder pushDebugGroup:@"Shadow Pass"];
        shadowRenderEncoder.label = @"Shadow Render Pass";
        
        [shadowRenderEncoder setVertexBuffer:directionalLightPropertiesUniform offset:0 atIndex:viDirLightPropertiesBuffer];
        
        
        U4DEntity *child=uRootEntity;

        while (child!=NULL) {
            
            U4DRenderEntity *renderEntity=child->getRenderEntity();
            
            if(renderEntity!=nullptr){
                
                U4DRenderPipelineInterface* shadowPipe=renderEntity->getPipeline(U4DEngine::shadowPass);

                if (shadowPipe!=nullptr) {
                    shadowPipe->executePass(shadowRenderEncoder, child);
                }
                
            }
            
               child=child->next;

           }
        
        [shadowRenderEncoder popDebugGroup];
        //end encoding
        [shadowRenderEncoder endEncoding];
//
//        U4DRenderPipelineInterface *offscreenPipeline=searchPipeline("offscreenpipeline");
//
//        id <MTLRenderCommandEncoder> offscreenRenderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:offscreenPipeline->mtlRenderPassDescriptor];
//
//        [offscreenRenderEncoder pushDebugGroup:@"Offscreen pass"];
//        offscreenRenderEncoder.label=@"Offscreen render pass";
//
//        child=uRootEntity;
//
//        while (child!=NULL) {
//
//            U4DRenderEntity *renderEntity=child->getRenderEntity();
//
//            if(renderEntity!=nullptr){
//
//                U4DRenderPipelineInterface* renderPipeline=renderEntity->getPipeline(U4DEngine::offscreenPass);
//
//                if (renderPipeline!=nullptr) {
//                    renderPipeline->executePass(offscreenRenderEncoder, child);
//                }
//
//            }
//
//               child=child->next;
//
//           }
//
//        [offscreenRenderEncoder popDebugGroup];
//        [offscreenRenderEncoder endEncoding];
        
        //G-Buffer Pass
//        U4DRenderPipelineInterface *gBufferPipeline=searchPipeline("gbufferpipeline");
//
//        id <MTLRenderCommandEncoder> gBufferRenderEncoder =
//        [uCommandBuffer renderCommandEncoderWithDescriptor:gBufferPipeline->mtlRenderPassDescriptor];
//
//        [gBufferRenderEncoder pushDebugGroup:@"G-Buffer Pass"];
//        gBufferRenderEncoder.label = @"G-Buffer Render Pass";
//
//        [gBufferRenderEncoder setVertexBuffer:globalDataUniform offset:0 atIndex:viGlobalDataBuffer];
//
//        [gBufferRenderEncoder setVertexBuffer:directionalLightPropertiesUniform offset:0 atIndex:viDirLightPropertiesBuffer];
//
//        [gBufferRenderEncoder setFragmentBuffer:globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];
//
//        [gBufferRenderEncoder setFragmentBuffer:directionalLightPropertiesUniform offset:0 atIndex:fiDirLightPropertiesBuffer];
//
//        gBufferPipeline->inputTexture=shadowPipeline->targetTexture;
//
//        child=uRootEntity;
//
//        while (child!=NULL) {
//
//            U4DRenderEntity *renderEntity=child->getRenderEntity();
//
//            if(renderEntity!=nullptr){
//
//                U4DRenderPipelineInterface* gBufferPipeline=renderEntity->getPipeline(U4DEngine::gBufferPass);
//
//                if (gBufferPipeline!=nullptr) {
//                    gBufferPipeline->executePass(gBufferRenderEncoder, child);
//                }
//
//            }
//
//               child=child->next;
//
//           }
//
//        [gBufferRenderEncoder popDebugGroup];
//        //end encoding
//        [gBufferRenderEncoder endEncoding];

        MTLRenderPassDescriptor * mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
               mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
               mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
               mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        
        //blit Encoder Pass
    
//        id<MTLBlitCommandEncoder> blitCommandEncoder=uCommandBuffer.blitCommandEncoder;
//
//        [blitCommandEncoder copyFromTexture:gBufferPipeline->depthTexture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0.0, 0.0, 0.0) sourceSize:MTLSizeMake(director->getMTLView().drawableSize.width,director->getMTLView().drawableSize.height,1) toTexture:mtlRenderPassDescriptor.depthAttachment.texture destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0.0, 0.0, 0.0)];
//
//        [blitCommandEncoder endEncoding];
//
//        mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
//               mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
//               mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
//               mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
//
//        mtlRenderPassDescriptor.depthAttachment.clearDepth=1.0;
//        mtlRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
//        mtlRenderPassDescriptor.depthAttachment.loadAction=MTLLoadActionLoad;
//
//        //Composition Pass
//        U4DRenderPipelineInterface *compositionPipeline=searchPipeline("compositionpipeline");
//
//        id <MTLRenderCommandEncoder> compositionRenderEncoder =
//        [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];
//
//        if(compositionRenderEncoder!=nil){
//
//            [compositionRenderEncoder pushDebugGroup:@"Composition Pass"];
//            compositionRenderEncoder.label = @"Composition Render Pass";
//
//            compositionPipeline->albedoTexture=gBufferPipeline->albedoTexture;
//            compositionPipeline->normalTexture=gBufferPipeline->normalTexture;
//            compositionPipeline->positionTexture=gBufferPipeline->positionTexture;
//            compositionPipeline->depthTexture=gBufferPipeline->depthTexture;
//
//            [compositionRenderEncoder setFragmentBuffer:globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];
//
//            [compositionRenderEncoder setFragmentBuffer:directionalLightPropertiesUniform offset:0 atIndex:fiDirLightPropertiesBuffer];
//
//            [compositionRenderEncoder setFragmentBuffer:pointLightsPropertiesUniform offset:0 atIndex:fiPointLightsPropertiesBuffer];
//
//            compositionPipeline->executePass(compositionRenderEncoder);
//
//            [compositionRenderEncoder popDebugGroup];
//            //end encoding
//            [compositionRenderEncoder endEncoding];
//
//        }
        
        //Final Pass

            U4DRenderPipelineInterface *modelPipeline=searchPipeline("modelpipeline");
        id <MTLRenderCommandEncoder> finalCompRenderEncoder =
        [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];

        if(finalCompRenderEncoder!=nil){

            [finalCompRenderEncoder pushDebugGroup:@"Final Comp Pass"];
            finalCompRenderEncoder.label = @"Final Comp Render Pass";

            [finalCompRenderEncoder setVertexBuffer:globalDataUniform offset:0 atIndex:viGlobalDataBuffer];

            [finalCompRenderEncoder setVertexBuffer:directionalLightPropertiesUniform offset:0 atIndex:viDirLightPropertiesBuffer];

            [finalCompRenderEncoder setFragmentBuffer:globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];

            [finalCompRenderEncoder setFragmentBuffer:directionalLightPropertiesUniform offset:0 atIndex:fiDirLightPropertiesBuffer];

            modelPipeline->inputTexture=shadowPipeline->targetTexture;

            child=uRootEntity;

            while (child!=NULL) {

                U4DRenderEntity *renderEntity=child->getRenderEntity();

                if(renderEntity!=nullptr){

                    U4DRenderPipelineInterface* renderPipeline=renderEntity->getPipeline(U4DEngine::finalPass);

                    if (renderPipeline!=nullptr) {
                        renderPipeline->executePass(finalCompRenderEncoder, child);
                    }

                }

                child=child->next;

               }

            [finalCompRenderEncoder popDebugGroup];
            //end encoding
            [finalCompRenderEncoder endEncoding];

        }

    }

    U4DRenderPipelineInterface* U4DRenderManager::searchPipeline(std::string uPipelineName){
        
        U4DRenderPipelineInterface *pipeline=nullptr;
        
        for(const auto &n:renderingPipelineContainer){
                
            if (n->getName().compare(uPipelineName)==0) {
                
                pipeline=n;
                break;
                
            }
            
        }
        
        return pipeline;
    }
 
    void U4DRenderManager::addRenderPipeline(U4DRenderPipelineInterface* uRenderPipeline){
        renderingPipelineContainer.push_back(uRenderPipeline);
    }
    
}

