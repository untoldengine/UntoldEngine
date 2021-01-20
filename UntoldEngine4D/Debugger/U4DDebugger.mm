//
//  U4DDebugger.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/4/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DDebugger.h"
#include "CommonProtocols.h"
#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "U4DCallback.h"
#include "U4DWindow.h"
#include "U4DDirector.h"
#include "U4DStaticModel.h"
#include "U4DProfilerManager.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"

namespace U4DEngine {

    U4DDebugger* U4DDebugger::instance=0;

    U4DDebugger::U4DDebugger():enableDebugger(false),uiLoaded(false),consoleLabel(nullptr),profilerLabel(nullptr){
        
        scheduler=new U4DCallback<U4DDebugger>;
        
        timer=new U4DTimer(scheduler);
        
    }
        
    U4DDebugger::~U4DDebugger(){
        
        //unsubscribe the timer
        scheduler->unScheduleTimer(timer);
        
        delete scheduler;
        delete timer;
        
    }
        
    U4DDebugger* U4DDebugger::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DDebugger();
            
        }
        
        return instance;
    }

    std::string U4DDebugger::getEntitiesInScenegraph(){
        
        std::string entitiesNames;
        
        U4DEntity *child=world->next;
        
        while (child!=nullptr) {
            
            if(child->getEntityType()==U4DEngine::MODEL){
                entitiesNames=entitiesNames+"\n "+child->getName();
            }
            
            child=child->next;
        }
        
        return entitiesNames;
    }

    void U4DDebugger::setEnableDebugger(bool uValue, U4DWorld *uWorld){
        enableDebugger=uValue;
        
        if (uiLoaded==false) {
            
            world=uWorld;
            
            //create layer manager
            U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

            //set this view (U4DWorld subclass) to the layer Manager
            layerManager->setWorld(world);

            //create Layers
            U4DLayer* engineProfilerLayer=new U4DLayer("engineProfilerLayer");

            consoleLabel=new U4DText("uiFont");
            consoleLabel->setText("Console");
            consoleLabel->translateTo(-0.7,0.7,0.0);
            
            profilerLabel=new U4DText("uiFont");
            profilerLabel->setText("Profiler");
            profilerLabel->translateTo(-0.7,0.6,0.0);
            
            checkboxShowProfiler=new U4DEngine::U4DCheckbox("checkboxProfiler",0.5,0.6,20.0,20.0,"Run Profiler","uiFont");
            
            checkboxShowNarrowPhaseVolume=new U4DEngine::U4DCheckbox("checkboxNarrowPhase",0.5,0.5,20.0,20.0,"Draw Narrow Phase Volume","uiFont");
            
            checkboxShowBroadPhaseVolume=new U4DEngine::U4DCheckbox("checkboxBroadPhase",0.5,0.4,20.0,20.0,"Draw Broad Phase Volume","uiFont");

            engineProfilerLayer->addChild(consoleLabel);
            engineProfilerLayer->addChild(profilerLabel);
            engineProfilerLayer->addChild(checkboxShowProfiler);
            engineProfilerLayer->addChild(checkboxShowNarrowPhaseVolume);
            engineProfilerLayer->addChild(checkboxShowBroadPhaseVolume);

            layerManager->addLayerToContainer(engineProfilerLayer);

            //push layer
            layerManager->pushLayer("engineProfilerLayer");
            
            //create a callback for checkbox profiler
            U4DCallback<U4DDebugger>* checkboxShowProfilerCallback=new U4DCallback<U4DDebugger>;

            checkboxShowProfilerCallback->scheduleClassWithMethod(this, &U4DDebugger::actionCheckboxShowProfiler);

            checkboxShowProfiler->setCallbackAction(checkboxShowProfilerCallback);
            
            //create a callback for checkbox show broad phase
            U4DCallback<U4DDebugger>* checkboxShowBroadPhaseCallback=new U4DCallback<U4DDebugger>;

            checkboxShowBroadPhaseCallback->scheduleClassWithMethod(this, &U4DDebugger::actionCheckboxShowBroadPhaseVolume);

            checkboxShowBroadPhaseVolume->setCallbackAction(checkboxShowBroadPhaseCallback);
            
            //create a callback for checkbox show narrow phase
           U4DCallback<U4DDebugger>* checkboxShowNarrowPhaseCallback=new U4DCallback<U4DDebugger>;

           checkboxShowNarrowPhaseCallback->scheduleClassWithMethod(this, &U4DDebugger::actionCheckboxShowNarrowPhaseVolume);

           checkboxShowNarrowPhaseVolume->setCallbackAction(checkboxShowNarrowPhaseCallback);

           scheduler->scheduleClassWithMethodAndDelay(this, &U4DDebugger::runDebugger, timer,1.0, true);
            
            uiLoaded=true;
            
        }
    }
    
    void U4DDebugger::runDebugger(){
        
        U4DDirector *director=U4DDirector::sharedInstance();
                    U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
                    
        float fps=director->getFPS();
        std::string profilerData=profilerManager->getProfileLog();
        
        consoleLabel->log("Console:\n FPS Avg: %f",fps);

        profilerLabel->log("Profiler:\n %s",profilerData.c_str());
        
        if (enableShaderReload==true) {
            
            //search for pipeline
            U4DEngine::U4DRenderManager *renderManager=U4DEngine::U4DRenderManager::sharedInstance();
            
            U4DEngine::U4DRenderPipelineInterface *pipeline=renderManager->searchPipeline(pipelineToReload);
            
            pipeline->hotReloadShaders(shaderFilePath,vertexShaderName,fragmentShaderName);
            
            enableShaderReload=false;
            
        }
        
    }
    bool U4DDebugger::getEnableDebugger(){
        
        return enableDebugger;
    
    }

    void U4DDebugger::reloadShader(std::string uPipelineToReload, std::string uFilepath, std::string uVertexShader, std::string uFragmentShader){
     
        enableShaderReload=true;
        pipelineToReload=uPipelineToReload;
        shaderFilePath=uFilepath;
        vertexShaderName=uVertexShader;
        fragmentShaderName=uFragmentShader;
        
    }

    void U4DDebugger::actionCheckboxShowProfiler(){
        
        U4DEngine::U4DProfilerManager *profilerManager=U4DEngine::U4DProfilerManager::sharedInstance();
        
        if (checkboxShowProfiler->getIsPressed()) {
            
            
            profilerManager->setEnableProfiler(true);
            
                        
        }else if(checkboxShowProfiler->getIsReleased()){
        
            profilerManager->setEnableProfiler(false);
            
        }
        
    }

    void U4DDebugger::actionCheckboxShowBroadPhaseVolume(){
        
        U4DEntity *child=world->next;
        
        if (checkboxShowBroadPhaseVolume->getIsPressed()) {
                   
           while (child!=nullptr) {
               
               if(child->isCollisionBehaviorEnabled()==true){
                   U4DStaticModel *model=dynamic_cast<U4DStaticModel*>(child);
                   model->setBroadPhaseBoundingVolumeVisibility(true);
               }
               
               child=child->next;
           }
                   
       }else if(checkboxShowBroadPhaseVolume->getIsReleased()){
       
           while (child!=nullptr) {
               
               if(child->isCollisionBehaviorEnabled()==true){
                   U4DStaticModel *model=dynamic_cast<U4DStaticModel*>(child);
                   model->setBroadPhaseBoundingVolumeVisibility(false);
               }
               
               child=child->next;
           }
           
       }
        
    }

    void U4DDebugger::actionCheckboxShowNarrowPhaseVolume(){
        
        U4DEntity *child=world->next;
         
         if (checkboxShowNarrowPhaseVolume->getIsPressed()) {
                    
            while (child!=nullptr) {
                
                if(child->isCollisionBehaviorEnabled()==true){
                    U4DStaticModel *model=dynamic_cast<U4DStaticModel*>(child);
                    model->setNarrowPhaseBoundingVolumeVisibility(true);
                }
                
                child=child->next;
            }
                    
        }else if(checkboxShowNarrowPhaseVolume->getIsReleased()){
        
            while (child!=nullptr) {
                
                if(child->isCollisionBehaviorEnabled()==true){
                    U4DStaticModel *model=dynamic_cast<U4DStaticModel*>(child);
                    model->setNarrowPhaseBoundingVolumeVisibility(false);
                }
                
                child=child->next;
            }
            
        }
        
    }

}
