//
//  U4DBallStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateManager.h"
#include "U4DBall.h"

#include "U4DLogger.h"

namespace U4DEngine {

    U4DBallStateManager::U4DBallStateManager(U4DBall *uBall):ball(uBall),previousState(nullptr),currentState(nullptr),changeStateRequest(false){
        
    }

    U4DBallStateManager::~U4DBallStateManager(){
        
    }

    void U4DBallStateManager::update(double dt){
        
        if (changeStateRequest==false) {
            
            currentState->execute(ball, dt);
        
        }else if(isSafeToChangeState()){
            
            changeState(nextState);
        }
        
    }

    void U4DBallStateManager::changeState(U4DBallStateInterface *uState){
        
        if(currentState!=uState){
            
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
            
//            U4DLogger *logger=U4DLogger::sharedInstance();
//            logger->log("Ball's Current State %s",currentState->name.c_str());
            
        }
        
    }

    bool U4DBallStateManager::isSafeToChangeState(){
        
        if (currentState!=NULL) {
            return currentState->isSafeToChangeState(ball);
        }else{
            return true;
        }
        
    }

    void U4DBallStateManager::safeChangeState(U4DBallStateInterface *uState){
        
        changeStateRequest=true;
        nextState=uState;
        
    }

    bool U4DBallStateManager::handleMessage(Message &uMsg){
    
        if(currentState!=nullptr){
            return currentState->handleMessage(ball, uMsg);
        }else{
            return false;
        }
    
    }

    U4DBallStateInterface *U4DBallStateManager::getCurrentState(){
        
        return currentState;
        
    }

    U4DBallStateInterface *U4DBallStateManager::getPreviousState(){
        
        return previousState;
        
    }

    std::string U4DBallStateManager::getCurrentStateName(){
        return currentState->name;
    }
}
