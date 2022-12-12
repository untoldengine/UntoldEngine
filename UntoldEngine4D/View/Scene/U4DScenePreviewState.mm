//
//  U4DScenePreviewState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/10/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DScenePreviewState.h"
namespace U4DEngine {

    U4DScenePreviewState* U4DScenePreviewState::instance=0;

    U4DScenePreviewState::U4DScenePreviewState():didGameLogicInit(false){

    }

    U4DScenePreviewState::~U4DScenePreviewState(){

    }

    U4DScenePreviewState* U4DScenePreviewState::sharedInstance(){

    if (instance==0) {
        instance=new U4DScenePreviewState();
    }

    return instance;

    }

    void U4DScenePreviewState::enter(U4DScene *uScene){
        
        uScene->setPauseScene(false);
        
    }
        
    void U4DScenePreviewState::execute(U4DScene *uScene, double dt){
        
        if(!uScene->getPauseScene()){
            
            safeToChangeState=false;
            
            //update the game controller
            uScene->gameController->update(dt);
            
            //if main scene world finished loading, then change scene
            //update the entity manager
            uScene->gameWorld->entityManager->update(dt); //need to add dt to view
            
        }
        
    }

    void U4DScenePreviewState::render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer){
        
        uScene->gameWorld->entityManager->render(uCommandBuffer);
        
        safeToChangeState=true;
    }
            
    
    void U4DScenePreviewState::exit(U4DScene *uScene){
        
        uScene->setPauseScene(true);
        
    }

    bool U4DScenePreviewState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
