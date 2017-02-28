//
//  SoccerBallStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerBallStateManager.h"
#include "SoccerBall.h"


SoccerBallStateManager::SoccerBallStateManager(SoccerBall *uBall):ball(uBall),previousState(NULL),currentState(NULL),changeStateRequest(false){
    
}

SoccerBallStateManager::~SoccerBallStateManager(){
    
}

void SoccerBallStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(ball, dt);
        
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
    
}

void SoccerBallStateManager::safeChangeState(SoccerBallStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

void SoccerBallStateManager::changeState(SoccerBallStateInterface *uState){
    
    //keep a record of previous state
    previousState=currentState;
    
    //call the exit method of the existing state
    if (currentState!=NULL) {
        currentState->exit(ball);
    }
    
    //change state to new state
    currentState=uState;
    
    //call the entry method of the new state
    currentState->enter(ball);
    
    changeStateRequest=false;
    
}

bool SoccerBallStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(ball);
    }else{
        return true;
    }
    
}
