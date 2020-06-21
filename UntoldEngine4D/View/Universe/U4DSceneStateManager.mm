//
//  U4DSceneStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DSceneStateManager.h"

namespace U4DEngine{

    U4DSceneStateManager::U4DSceneStateManager(U4DScene *uScene):scene(uScene),previousState(nullptr),currentState(nullptr){
        
    }

    U4DSceneStateManager::~U4DSceneStateManager(){
        
    }

    void U4DSceneStateManager::changeState(U4DSceneStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(scene);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(scene);
        
        changeStateRequest=false;
        
    }

    void U4DSceneStateManager::update(double dt){
        
        if (changeStateRequest==false) {
            currentState->execute(scene, dt);
        }else if (isSafeToChangeState()){
            changeState(nextState);
        }
        
    }

    void U4DSceneStateManager::render(id <MTLRenderCommandEncoder> uRenderEncoder){
        
        currentState->render(scene, uRenderEncoder);
        
    }

    void U4DSceneStateManager::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
        currentState->renderShadow(scene, uRenderShadowEncoder, uShadowTexture);
        
    }


    U4DSceneStateInterface *U4DSceneStateManager::getCurrentState(){
        
        return currentState;
        
    }

    bool U4DSceneStateManager::isSafeToChangeState(){
        
        if (currentState!=nullptr) {
            return currentState->isSafeToChangeState(scene);
        }else{
            return true;
        }
        
    }

    void U4DSceneStateManager::safeChangeState(U4DSceneStateInterface *uState){
        
        changeStateRequest=true;
        nextState=uState;
        
    }


}
