//
//  U4DSceneLoadingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneLoadingState.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneActiveState.h"
#include "U4DLayerManager.h"
#include "U4DScheduler.h"
#include "U4DCamera.h"

namespace U4DEngine {

    U4DSceneLoadingState* U4DSceneLoadingState::instance=0;

    U4DSceneLoadingState::U4DSceneLoadingState():safeToChangeState(false){

    }

    U4DSceneLoadingState::~U4DSceneLoadingState(){

    }

    U4DSceneLoadingState* U4DSceneLoadingState::sharedInstance(){

        if (instance==0) {
            instance=new U4DSceneLoadingState();
        }

        return instance;

    }

    void U4DSceneLoadingState::enter(U4DScene *uScene){
        
        //Load your loading scene world
        
        uScene->loadingWorld->init();
        
        //Load your main scene world in multithread
        uScene->initializeMultithreadofComponents();
        
        
    }
        
    void U4DSceneLoadingState::execute(U4DScene *uScene, double dt){
        
        safeToChangeState=false;
        
        //if main scene world finished loading, then change scene
        //update the entity manager
        uScene->loadingWorld->entityManager->update(dt); //need to add dt to view
        
        if (uScene->componentsMultithreadLoaded) {
            
            uScene->getSceneStateManager()->changeState(U4DSceneActiveState::sharedInstance());
            
        }
        
    }

    void U4DSceneLoadingState::render(U4DScene *uScene, id <MTLCommandBuffer> uCommandBuffer){
        
        uScene->loadingWorld->entityManager->render(uCommandBuffer);
        
        safeToChangeState=true;
        
    }
        
    
    void U4DSceneLoadingState::exit(U4DScene *uScene){
        
        //unload load scene world
        
        
        
    }

    bool U4DSceneLoadingState::isSafeToChangeState(U4DScene *uScene){
        
        //do other things here before changing the state
        
        return true;
        
    }

}
