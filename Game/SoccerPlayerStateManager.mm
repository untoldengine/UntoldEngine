//
//  SoccerPlayerStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerStateManager.h"
#include "SoccerPlayer.h"

SoccerPlayerStateManager::SoccerPlayerStateManager(SoccerPlayer *uPlayer):player(uPlayer),previousState(NULL),currentState(NULL){
    
}

SoccerPlayerStateManager::~SoccerPlayerStateManager(){
    
}

void SoccerPlayerStateManager::execute(){
    
    currentState->execute(player);
    
}

void SoccerPlayerStateManager::changeState(SoccerPlayerStateInterface *uState){
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    currentState->exit(player);
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(player);
    
}

void SoccerPlayerStateManager::setInitialState(SoccerPlayerStateInterface *uState){
    
    currentState=uState;
    
}

