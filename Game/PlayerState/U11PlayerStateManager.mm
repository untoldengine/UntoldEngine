//
//  U11PlayerStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerStateManager.h"
#include "U11Player.h"


U11PlayerStateManager::U11PlayerStateManager(U11Player *uPlayer):player(uPlayer),previousState(NULL),currentState(NULL),changeStateRequest(false){
    
}

U11PlayerStateManager::~U11PlayerStateManager(){
    
}

void U11PlayerStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(player, dt);
    
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
    
}

void U11PlayerStateManager::safeChangeState(U11PlayerStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

void U11PlayerStateManager::changeState(U11PlayerStateInterface *uState){
    
    //remove animation
    player->removeCurrentPlayingAnimation();
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    if (currentState!=NULL) {
        currentState->exit(player);
    }
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(player);
    
    //play new animation
    player->playAnimation();
    
    changeStateRequest=false;
    
}

bool U11PlayerStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(player);
    }else{
        return true;
    }

}

bool U11PlayerStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(player, uMsg);
}


