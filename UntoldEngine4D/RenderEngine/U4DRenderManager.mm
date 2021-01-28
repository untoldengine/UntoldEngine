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
#include "U4DShadowPass.h"
#include "U4DFinalPass.h"
#include "U4DOffscreenPass.h"
#include "U4DGBufferPass.h"
#include "U4DCompositionPass.h"

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
        
        
        updateDirLightDataUniforms();
        updatePointLightDataUniforms();
        updateGlobalDataUniforms();
        
        U4DShadowPass shadowPass("shadowpipeline");
        shadowPass.executePass(uCommandBuffer, uRootEntity, nullptr);
        
//        U4DOffscreenPass offscreenPass("offscreenpipeline");
//        offscreenPass.executePass(uCommandBuffer, uRootEntity, nullptr);
        
//        U4DGBufferPass gBufferPass("gbufferpipeline");
//        gBufferPass.executePass(uCommandBuffer, uRootEntity, &shadowPass);
//
//        U4DCompositionPass compositionPass("compositionpipeline");
//        compositionPass.executePass(uCommandBuffer, uRootEntity, &gBufferPass);
        
        U4DFinalPass finalPass("modelpipeline");
        finalPass.executePass(uCommandBuffer, uRootEntity, &shadowPass);
        

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

