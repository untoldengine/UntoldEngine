//
//  U11TeamStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11TeamStateManager.h"
#include "U11Team.h"

U11TeamStateManager::U11TeamStateManager(U11Team *uTeam):team(uTeam),previousState(NULL),currentState(NULL){
    
}

U11TeamStateManager::~U11TeamStateManager(){
    
}

void U11TeamStateManager::update(double dt){
    
    currentState->execute(team, dt);
    
}


void U11TeamStateManager::changeState(U11TeamStateInterface *uState){
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    if (currentState!=NULL) {
        currentState->exit(team);
    }
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(team);
    
}


bool U11TeamStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(team, uMsg);
}

U11TeamStateInterface *U11TeamStateManager::getCurrentState(){
    
    return currentState;
    
}
