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

namespace U4DEngine {

    U4DDebugger* U4DDebugger::instance=0;

    U4DDebugger::U4DDebugger():enableDebugger(false),uiLoaded(false),consoleLabel(nullptr),profilerLabel(nullptr),showBVHTree(false),bvhTree(nullptr){
        
        
        
    }
        
    U4DDebugger::~U4DDebugger(){
        
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

    void U4DDebugger::update(double dt){
        
        if(enableDebugger && consoleLabel!=nullptr){
            
            U4DDirector *director=U4DDirector::sharedInstance();
            U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
            
            float fps=director->getFPS();
//            std::string entitiesNames=getEntitiesInScenegraph();
            
            std::string profilerData=profilerManager->getProfileLog();
            
            consoleLabel->log("Console:\n FPS Avg: %f",fps);

//            entitiesLabel->log("Entities in Scenegraph:\n %s",entitiesNames.c_str());
            
            profilerLabel->log("Profiler:\n %s",profilerData.c_str());
            
        }
            
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

            checkboxShowBVH=new U4DEngine::U4DCheckbox("checkboxBVH",0.5,0.7,20.0,20.0,"Draw Collision BVH","uiFont");
            
            checkboxShowProfiler=new U4DEngine::U4DCheckbox("checkboxProfiler",0.5,0.6,20.0,20.0,"Run Profiler","uiFont");
            
            checkboxShowNarrowPhaseVolume=new U4DEngine::U4DCheckbox("checkboxNarrowPhase",0.5,0.5,20.0,20.0,"Draw Narrow Phase Volume","uiFont");
            
            checkboxShowBroadPhaseVolume=new U4DEngine::U4DCheckbox("checkboxBroadPhase",0.5,0.4,20.0,20.0,"Draw Broad Phase Volume","uiFont");

            engineProfilerLayer->addChild(consoleLabel);
            engineProfilerLayer->addChild(profilerLabel);
            engineProfilerLayer->addChild(checkboxShowBVH);
            engineProfilerLayer->addChild(checkboxShowProfiler);
            engineProfilerLayer->addChild(checkboxShowNarrowPhaseVolume);
            engineProfilerLayer->addChild(checkboxShowBroadPhaseVolume);

            layerManager->addLayerToContainer(engineProfilerLayer);

            //push layer
            layerManager->pushLayer("engineProfilerLayer");

            //create a callback for checkbox bvh
            U4DCallback<U4DDebugger>* checkboxShowBVHCallback=new U4DCallback<U4DDebugger>;

            checkboxShowBVHCallback->scheduleClassWithMethod(this, &U4DDebugger::actionCheckboxShowBVH);

            checkboxShowBVH->setCallbackAction(checkboxShowBVHCallback);
            
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

        
            uiLoaded=true;
            
        }
    }
        
    bool U4DDebugger::getEnableDebugger(){
        
        return enableDebugger;
    
    }

    void U4DDebugger::loadBVHTreeData(std::vector<U4DPoint3n> &uMin, std::vector<U4DPoint3n> &uMax){
        
        bvhTree->updateBoundingVolume(uMin, uMax);
        
    }

    bool U4DDebugger::getShowBVHTree(){
        return showBVHTree;
    }

    void U4DDebugger::actionCheckboxShowBVH(){
        
        if (checkboxShowBVH->getIsPressed()) {
            
            bvhTree=new U4DBoundingBVH();
            
            U4DPoint3n minPoint(0.0,0.0,0.0);
            U4DPoint3n maxPoint(0.0,0.0,0.0);
            std::vector<U4DPoint3n> minPoints{minPoint};
            std::vector<U4DPoint3n> maxPoints{maxPoint};
            bvhTree->computeBoundingVolume(minPoints, maxPoints);
            bvhTree->loadRenderingInformation();
            bvhTree->setVisibility(true);
            world->addChild(bvhTree);
            
            showBVHTree=true;
                        
        }else if(checkboxShowBVH->getIsReleased()){
            
            world->removeChild(bvhTree);
            delete bvhTree;
            
            showBVHTree=false;
            
        }
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
