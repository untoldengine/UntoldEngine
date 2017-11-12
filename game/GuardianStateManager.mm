//
//  GuardianStateManager.c
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "GuardianStateManager.h"
#include "GuardianModel.h"


GuardianStateManager::GuardianStateManager(GuardianModel *uGuardian):guardian(uGuardian),previousState(NULL),currentState(NULL),changeStateRequest(false){
    
}

GuardianStateManager::~GuardianStateManager(){
    
}

void GuardianStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(guardian, dt);
        
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
    
}

void GuardianStateManager::safeChangeState(GuardianStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

void GuardianStateManager::changeState(GuardianStateInterface *uState){
    
    //remove animation
    //guardian->removeCurrentPlayingAnimation();
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    if (currentState!=NULL) {
        currentState->exit(guardian);
    }
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(guardian);
    
    //play new animation
    //guardian->playAnimation();
    
    changeStateRequest=false;
    
}

bool GuardianStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(guardian);
    }else{
        return true;
    }
    
}

bool GuardianStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(guardian, uMsg);
}

GuardianStateInterface *GuardianStateManager::getCurrentState(){
    
    return currentState;
    
}
