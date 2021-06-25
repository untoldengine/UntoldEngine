//
//  U4DScenePlayState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/20/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DScenePlayState.h"
#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DWorld.h"
#include "U4DLogger.h"
#include "U4DScriptBindManager.h"
#include "U4DScriptInstanceManager.h"

namespace U4DEngine {

    U4DScenePlayState* U4DScenePlayState::instance=0;

    U4DScenePlayState::U4DScenePlayState(){

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

        safeToChangeState=false;
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        logger->log("Entering Play Mode");
        
        
    }
        
    void U4DScenePlayState::execute(U4DScene *uScene, double dt){
        
        safeToChangeState=false;
        
        //update the game controller
        uScene->gameController->update(dt);
        
        //update the game model
        uScene->gameEditingLogic->update(dt);
        
        //if main scene world finished loading, then change scene
        //update the entity manager
        uScene->editingWorld->entityManager->update(dt); //need to add dt to view
        
    }

    void U4DScenePlayState::render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer){
        
        uScene->editingWorld->entityManager->render(uCommandBuffer);
        
        safeToChangeState=true;
    }
            
    
    void U4DScenePlayState::exit(U4DScene *uScene){
        
       
    }

    bool U4DScenePlayState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
