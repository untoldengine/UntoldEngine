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

    U4DSceneEditingState::U4DSceneEditingState(){

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

        U4DLogger *logger=U4DLogger::sharedInstance();
        
        logger->log("Entering Edit Mode");
        
        safeToChangeState=false;
        
        U4DSceneManager *sceneManager=U4DSceneManager::sharedInstance();
        
        uScene->editingWorld->setGameController(uScene->gameController);
        uScene->editingWorld->setGameLogic(uScene->gameLogic);
        
        uScene->gameController->setGameWorld(uScene->editingWorld);
        uScene->gameController->setGameLogic(uScene->gameLogic);
        
        uScene->gameLogic->setGameWorld(uScene->editingWorld);
        uScene->gameLogic->setGameController(sceneManager->getGameController());
        uScene->gameLogic->setGameEntityManager(uScene->editingWorld->getEntityManager());
        
        
        uScene->editingWorld->init();
        uScene->gameLogic->init();
        
        //enable profiler
        sceneManager->enableSceneProfiling();
        
    }
        
    void U4DSceneEditingState::execute(U4DScene *uScene, double dt){
        
        if(!uScene->getPauseScene()){
            
            safeToChangeState=false;
            
            //update the game controller
            uScene->gameController->update(dt);
            
            //update the game model
            uScene->gameLogic->update(dt);
            
            //if main scene world finished loading, then change scene
            //update the entity manager
            uScene->editingWorld->entityManager->update(dt); //need to add dt to view
            
        }
        
        
    }

    void U4DSceneEditingState::render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer){
        
        uScene->editingWorld->entityManager->render(uCommandBuffer);
        
        safeToChangeState=true; 
    }
            
    
    void U4DSceneEditingState::exit(U4DScene *uScene){
     
        //Load your loading scene world
        uScene->editingWorld->removeAllModelChildren();
    }

    bool U4DSceneEditingState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
