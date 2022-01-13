//
//  U4DTeamStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DTeamStateManager.h"
#include "U4DTeam.h"
#include "U4DLogger.h"

namespace U4DEngine{

U4DTeamStateManager::U4DTeamStateManager(U4DTeam *uTeam):team(uTeam),previousState(nullptr),currentState(nullptr),changeStateRequest(false){
    
}

U4DTeamStateManager::~U4DTeamStateManager(){
    
}

void U4DTeamStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(team,dt);
    
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
}

void U4DTeamStateManager::changeState(U4DTeamStateInterface *uState){

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
    
    changeStateRequest=false;
    
    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
    logger->log("U4DTeam Current State %s",currentState->name.c_str());
    
}

bool U4DTeamStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(team);
    }else{
        return true;
    }
    
}

void U4DTeamStateManager::safeChangeState(U4DTeamStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

bool U4DTeamStateManager::handleMessage(Message &uMsg){
    
    if (currentState!=NULL) {
            return currentState->handleMessage(team, uMsg);
    }else{
        return false;
    }
}

U4DTeamStateInterface *U4DTeamStateManager::getCurrentState(){
    
    return currentState;
    
}

U4DTeamStateInterface *U4DTeamStateManager::getPreviousState(){
    
    return previousState;
    
}

}
