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
#include "U4DStaticAction.h"
#include "U4DProfilerManager.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DSlider.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DDebugger* U4DDebugger::instance=0;

U4DDebugger::U4DDebugger():enableDebugger(false),uiLoaded(false),enableShaderReload(false){
        
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
            U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
            
            profilerManager->setEnableProfiler(true);

           scheduler->scheduleClassWithMethodAndDelay(this, &U4DDebugger::runDebugger, timer,1.0, true);
            
            uiLoaded=true;
            
        }
    }
    
    void U4DDebugger::runDebugger(){
        
        U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        
        profilerData=profilerManager->getProfileLog();
        
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
     
        //set flag to reload a shader
        enableShaderReload=true;
        
        //pipeline and shader info
        pipelineToReload=uPipelineToReload;
        shaderFilePath=uFilepath;
        vertexShaderName=uVertexShader;
        fragmentShaderName=uFragmentShader;
        
    }

}
