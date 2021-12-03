//
//  U4DScenePlayState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/12/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScenePlayState.h"

namespace U4DEngine {

    U4DScenePlayState* U4DScenePlayState::instance=0;

    U4DScenePlayState::U4DScenePlayState():didGameLogicInit(false){

    }

    U4DScenePlayState::~U4DScenePlayState(){

    }

    U4DScenePlayState* U4DScenePlayState::sharedInstance(){

    if (instance==0) {
        instance=new U4DScenePlayState();
    }

    return instance;

    }

    void U4DScenePlayState::enter(U4DScene *uScene){
        
        uScene->setPauseScene(false);
        
        if(didGameLogicInit==false){
            uScene->gameLogic->init();
            didGameLogicInit=true;
        }
        
        
    }
        
    void U4DScenePlayState::execute(U4DScene *uScene, double dt){
        
        if(!uScene->getPauseScene()){
            
            safeToChangeState=false; 
            
            //update the game controller
            uScene->gameController->update(dt);
            
            //update the game model
            uScene->gameLogic->update(dt);
            
            //if main scene world finished loading, then change scene
            //update the entity manager
            uScene->gameWorld->entityManager->update(dt); //need to add dt to view
            
        }
        
    }

    void U4DScenePlayState::render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer){
        
        uScene->gameWorld->entityManager->render(uCommandBuffer);
        
        safeToChangeState=true;
    }
            
    
    void U4DScenePlayState::exit(U4DScene *uScene){
        
        uScene->setPauseScene(true);
        
    }

    bool U4DScenePlayState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
