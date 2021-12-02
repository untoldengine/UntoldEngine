//
//  U4DSceneEditingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneEditingState.h"
#include "U4DSceneManager.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DSceneEditingState* U4DSceneEditingState::instance=0;

    U4DSceneEditingState::U4DSceneEditingState():didWorldAndLogicInit(false){

    }

    U4DSceneEditingState::~U4DSceneEditingState(){

    }

    U4DSceneEditingState* U4DSceneEditingState::sharedInstance(){

    if (instance==0) {
        instance=new U4DSceneEditingState();
    }

    return instance;

    }

    void U4DSceneEditingState::enter(U4DScene *uScene){

        uScene->setPauseScene(true);
            
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        logger->log("Entering Edit Mode");
        
        safeToChangeState=false;
        
        if(didWorldAndLogicInit==false){
            
            U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
            
            uScene->gameWorld->init();
            uScene->gameLogic->init();
            
            //enable profiler
            sceneManager->enableSceneProfiling();
            
            didWorldAndLogicInit=true;
        }
        
    }
        
    void U4DSceneEditingState::execute(U4DScene *uScene, double dt){
        
        
        
    }

    void U4DSceneEditingState::render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer){
        
        uScene->gameWorld->entityManager->render(uCommandBuffer);
        
        safeToChangeState=true; 
    }
            
    
    void U4DSceneEditingState::exit(U4DScene *uScene){
        
    }

    bool U4DSceneEditingState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
