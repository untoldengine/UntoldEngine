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

void SoccerPlayerStateManager::execute(double dt){
    
    currentState->execute(player, dt);
    
}

void SoccerPlayerStateManager::changeState(SoccerPlayerStateInterface *uState){
    
    //remove animation
    player->removeCurrentPlayingAnimation();
    
    //remove all kinetic forces
    player->removeKineticForces();
    
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
    
}

void SoccerPlayerStateManager::setInitialState(SoccerPlayerStateInterface *uState){
    
    currentState=uState;
    
}

