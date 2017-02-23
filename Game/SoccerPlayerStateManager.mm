//
//  SoccerPlayerStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerStateManager.h"
#include "SoccerPlayer.h"


SoccerPlayerStateManager::SoccerPlayerStateManager(SoccerPlayer *uPlayer):player(uPlayer),previousState(NULL),currentState(NULL),changeStateRequest(false){
    
}

SoccerPlayerStateManager::~SoccerPlayerStateManager(){
    
}

void SoccerPlayerStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(player, dt);
    
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
    
}

void SoccerPlayerStateManager::safeChangeState(SoccerPlayerStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

void SoccerPlayerStateManager::changeState(SoccerPlayerStateInterface *uState){
    
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

bool SoccerPlayerStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(player);
    }else{
        return true;
    }

}


