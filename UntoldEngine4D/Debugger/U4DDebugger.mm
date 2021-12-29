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
#include "U4DDirector.h"
#include "U4DStaticAction.h"
#include "U4DProfilerManager.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DLogger.h"
#include "U4DNetworkManager.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"

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

            //create layer manager
            U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();

            //set this view (U4DWorld subclass) to the layer Manager
            layerManager->setWorld(world);

            //create Layers
            U4DLayer* engineProfilerLayer=new U4DLayer("engineProfilerLayer");

            consoleLabel=new U4DText("uiFont");
            consoleLabel->setText("Console");
            consoleLabel->translateTo(-0.7,0.7,0.0);

//            profilerLabel=new U4DText("uiFont");
//            profilerLabel->setText("Profiler");
//            profilerLabel->translateTo(0.5,0.7,0.0);
            
            serverConnectionLabel=new U4DText("uiFont");
            serverConnectionLabel->setText("Connected:");
            serverConnectionLabel->translateTo(-0.7,0.5,0.0);

//            U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
//            profilerManager->setEnableProfiler(true);
            

            engineProfilerLayer->addChild(consoleLabel);
            //engineProfilerLayer->addChild(profilerLabel);
            engineProfilerLayer->addChild(serverConnectionLabel);
            
            layerManager->addLayerToContainer(engineProfilerLayer);

            //push layer
            layerManager->pushLayer("engineProfilerLayer");

            scheduler->scheduleClassWithMethodAndDelay(this, &U4DDebugger::runDebugger, timer,1.0, true);

            uiLoaded=true;
            
        }
    }
    
    void U4DDebugger::runDebugger(){
        
        //U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        //std::string profilerData=profilerManager->getProfileLog();
        
        
        U4DDirector *director=U4DDirector::sharedInstance();
        float fps=director->getFPS();
        consoleLabel->log("Console:\n FPS Avg: %f",fps);
        
        //profilerLabel->log("Profiler:\n %s",profilerData.c_str());
        
        U4DNetworkManager *networkManager=U4DNetworkManager::sharedInstance();
        bool isConnected=networkManager->isConnectedToServer();
        serverConnectionLabel->log("Connected: %s",isConnected?"true":"false");
        
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
