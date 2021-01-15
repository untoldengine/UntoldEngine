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
#include "U4DLights.h"
#include "U4DDirector.h"
#include "U4DNumerical.h"
#include "U4DRenderEntity.h"

#include "U4DModelPipeline.h"
#include "U4DShadowRenderPipeline.h"
#include "U4DImagePipeline.h"
#include "U4DOffscreenPipeline.h"
#include "U4DSkyboxPipeline.h"
#include "U4DParticlesPipeline.h"
#include "U4DShaderEntityPipeline.h"
#include "U4DGeometryPipeline.h"
#include "U4DWorldPipeline.h"

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
        U4DScene *scene=sceneManager->getCurrentScene();
        
        //get the resolution of the display
        U4DVector2n resolution(director->getDisplayWidth(),director->getDisplayHeight());
        
        vector_float2 resolutionSIMD=numerical.convertToSIMD(resolution);
        
        UniformGlobalData uniformGlobalData;
        uniformGlobalData.time=scene->getGlobalTime(); //set the global time
        uniformGlobalData.resolution=resolutionSIMD; //set the display resolution
        
        memcpy(globalDataUniform.contents, (void*)&uniformGlobalData, sizeof(UniformGlobalData));
        
    }
        
    void U4DRenderManager::updateLightDataUniforms(){
        
        U4DLights *light=U4DLights::sharedInstance();
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
        
        UniformLightProperties lightProperties;
        
        lightProperties.lightShadowProjectionSpace=lightShadowProjectionSpaceSIMD;
        lightProperties.lightPosition=lightPositionSIMD;
        lightProperties.diffuseColor=diffuseColorSIMD;
        lightProperties.specularColor=specularColorSIMD;
        
        memcpy(lightPropertiesUniform.contents, (void*)&lightProperties, sizeof(UniformLightProperties));
        
    }

    void U4DRenderManager::initRenderPipelines(id <MTLDevice> uMTLDevice){
        
        //init global data buffer
        globalDataUniform=[uMTLDevice newBufferWithLength:sizeof(UniformGlobalData) options:MTLResourceStorageModeShared];
        
        //init light buffer
        lightPropertiesUniform=[uMTLDevice newBufferWithLength:sizeof(UniformLightProperties) options:MTLResourceStorageModeShared];
        
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
        
    }

    void U4DRenderManager::render(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity){
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        updateLightDataUniforms();
        updateGlobalDataUniforms();
        
        U4DRenderPipelineInterface *shadowPipeline=searchPipeline("shadowpipeline");
        
        id <MTLRenderCommandEncoder> shadowRenderEncoder =
        [uCommandBuffer renderCommandEncoderWithDescriptor:shadowPipeline->mtlRenderPassDescriptor];
        
        [shadowRenderEncoder pushDebugGroup:@"Shadow Pass"];
        shadowRenderEncoder.label = @"Shadow Render Pass";
        
        [shadowRenderEncoder setVertexBuffer:lightPropertiesUniform offset:0 atIndex:viLightPropertiesBuffer];
        
        
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

//        id <MTLRenderCommandEncoder> offscreenRenderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:offscreenPipeline->mtlRenderPassDescriptor];
//
//        [offscreenRenderEncoder pushDebugGroup:@"Offscreen pass"];
//        offscreenRenderEncoder.label=@"Offscreen render pass";
//
//        child=uRootEntity;
//
//        while (child!=NULL) {
//
//            if((child->getRenderPassFilter()&U4DEngine::offscreenRenderPass)==U4DEngine::offscreenRenderPass){
//
//                offscreenPipeline->executePass(offscreenRenderEncoder, child);
//
//            }
//
//               child=child->next;
//
//           }
//
//        [offscreenRenderEncoder popDebugGroup];
//        [offscreenRenderEncoder endEncoding];
        
        
        U4DRenderPipelineInterface *modelPipeline=searchPipeline("modelpipeline");
        
        MTLRenderPassDescriptor * mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
               mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
               mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
               mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        
        
        id <MTLRenderCommandEncoder> finalCompRenderEncoder =
        [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];
        
        if(finalCompRenderEncoder!=nil){
            
            [finalCompRenderEncoder pushDebugGroup:@"Final Comp Pass"];
            finalCompRenderEncoder.label = @"Final Comp Render Pass";
            
            [finalCompRenderEncoder setVertexBuffer:globalDataUniform offset:0 atIndex:viGlobalDataBuffer];
            
            [finalCompRenderEncoder setVertexBuffer:lightPropertiesUniform offset:0 atIndex:viLightPropertiesBuffer];
            
            [finalCompRenderEncoder setFragmentBuffer:globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];
            
            [finalCompRenderEncoder setFragmentBuffer:lightPropertiesUniform offset:0 atIndex:fiLightPropertiesBuffer];
            
            modelPipeline->inputTexture=shadowPipeline->targetTexture;
            
            U4DEntity *child=uRootEntity;

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

