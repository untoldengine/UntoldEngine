//
//  TeamStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "TeamStateManager.h"
#include "Team.h"
#include "U4DLogger.h"

TeamStateManager::TeamStateManager(Team *uTeam):team(uTeam),previousState(nullptr),currentState(nullptr),changeStateRequest(false){
    
}

TeamStateManager::~TeamStateManager(){
    
}

void TeamStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(team,dt);
    
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
}

void TeamStateManager::changeState(TeamStateInterface *uState){

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
    
//    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
//    logger->log("Current State %s",currentState->name.c_str());
    
}

bool TeamStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(team);
    }else{
        return true;
    }
    
}

void TeamStateManager::safeChangeState(TeamStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

bool TeamStateManager::handleMessage(Message &uMsg){
    
    return currentState->handleMessage(team, uMsg);
}

TeamStateInterface *TeamStateManager::getCurrentState(){
    
    return currentState;
    
}

TeamStateInterface *TeamStateManager::getPreviousState(){
    
    return previousState;
    
}
