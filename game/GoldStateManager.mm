//
//  GoldStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/6/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "GoldStateManager.h"
#include "GoldAsset.h"


GoldStateManager::GoldStateManager(GoldAsset *uGold):gold(uGold),previousState(NULL),currentState(NULL),changeStateRequest(false){
    
}

GoldStateManager::~GoldStateManager(){
    
}

void GoldStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(gold, dt);
        
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
    
}

void GoldStateManager::safeChangeState(GoldStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

void GoldStateManager::changeState(GoldStateInterface *uState){
    
    //remove animation
    //gold->removeCurrentPlayingAnimation();
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    if (currentState!=NULL) {
        currentState->exit(gold);
    }
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(gold);
    
    //play new animation
    //gold->playAnimation();
    
    changeStateRequest=false;
    
}

bool GoldStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(gold);
    }else{
        return true;
    }
    
}

bool GoldStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(gold, uMsg);
}

GoldStateInterface *GoldStateManager::getCurrentState(){
    
    return currentState;
    
}
