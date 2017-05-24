//
//  U11AIStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AIStateManager.h"
#include "U11AIStateInterface.h"


U11AIStateManager::U11AIStateManager(U11AISystem *uAISystem):aiSystem(uAISystem),previousState(NULL),currentState(NULL){
    
}

U11AIStateManager::~U11AIStateManager(){
    
}

void U11AIStateManager::update(double dt){
    
    currentState->execute(aiSystem, dt);
}

void U11AIStateManager::changeState(U11AIStateInterface *uState){
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    if (currentState!=NULL) {
        currentState->exit(aiSystem);
    }
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(aiSystem);
    
}

bool U11AIStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(aiSystem, uMsg);
    
}

U11AIStateInterface *U11AIStateManager::getCurrentState(){
    
    return currentState;
    
}
