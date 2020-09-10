//
//  PlayerStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "PlayerStateManager.h"
#include "Player.h"
#include "Foot.h"

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
    player->getAnimationManager()->removeCurrentPlayingAnimation();
    
    //pause collision with foot
    
    player->rightFoot->pauseCollisionBehavior(); 
    
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
    player->getAnimationManager()->playAnimation();
    
    changeStateRequest=false;
    
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

bool PlayerStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(player, uMsg);
}

PlayerStateInterface *PlayerStateManager::getCurrentState(){
    
    return currentState;
    
}

PlayerStateInterface *PlayerStateManager::getPreviousState(){
    
    return previousState;
    
}
