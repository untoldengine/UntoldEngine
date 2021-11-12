//
//  PlayerStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/11/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateManager.h"
#include "Player.h"
#include "Foot.h"
#include "U4DLogger.h"

PlayerStateManager::PlayerStateManager(Player *uPlayer):player(uPlayer),previousState(nullptr),currentState(nullptr),changeStateRequest(false){
    
}

PlayerStateManager::~PlayerStateManager(){
    
}

void PlayerStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(player, dt);
    
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
}

void PlayerStateManager::changeState(PlayerStateInterface *uState){
    
    //remove animation
    player->animationManager->removeCurrentPlayingAnimation();
    
    //pause collision with foot
    
    player->foot->kineticAction->pauseCollisionBehavior(); 
    
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
    player->animationManager->playAnimation();
    
    changeStateRequest=false;
    
    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
    logger->log("Player %s Current State %s",player->getName().c_str(),currentState->name.c_str());
    
}

bool PlayerStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(player);
    }else{
        return true;
    }
    
}

void PlayerStateManager::safeChangeState(PlayerStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

//bool PlayerStateManager::handleMessage(Message &uMsg){
//
//    if(currentState!=nullptr){
//        return currentState->handleMessage(player, uMsg);
//    }else{
//        return false;
//    }
//
//}

PlayerStateInterface *PlayerStateManager::getCurrentState(){
    
    return currentState;
    
}

PlayerStateInterface *PlayerStateManager::getPreviousState(){
    
    return previousState;
    
}
