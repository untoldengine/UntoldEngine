//
//  U11BallStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11BallStateManager.h"
#include "U11Ball.h"


U11BallStateManager::U11BallStateManager(U11Ball *uBall):ball(uBall),previousState(NULL),currentState(NULL),changeStateRequest(false){
    
}

U11BallStateManager::~U11BallStateManager(){
    
}

void U11BallStateManager::update(double dt){
    
    if (changeStateRequest==false) {
        
        currentState->execute(ball, dt);
        
    }else if(isSafeToChangeState()){
        
        changeState(nextState);
    }
    
    
}

void U11BallStateManager::safeChangeState(U11BallStateInterface *uState){
    
    changeStateRequest=true;
    nextState=uState;
    
}

void U11BallStateManager::changeState(U11BallStateInterface *uState){
    
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

bool U11BallStateManager::isSafeToChangeState(){
    
    if (currentState!=NULL) {
        return currentState->isSafeToChangeState(ball);
    }else{
        return true;
    }
    
}
