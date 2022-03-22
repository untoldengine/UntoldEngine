//
//  U4DPlayerStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateManager.h"
#include "U4DPlayer.h"
#include "U4DFoot.h"
#include "U4DLogger.h"

namespace U4DEngine {

    U4DPlayerStateManager::U4DPlayerStateManager(U4DPlayer *uPlayer):player(uPlayer),previousState(nullptr),currentState(nullptr),changeStateRequest(false){ 
        
    }

    U4DPlayerStateManager::~U4DPlayerStateManager(){
        
    }

    void U4DPlayerStateManager::update(double dt){
        
        if (changeStateRequest==false) {
            
            currentState->execute(player, dt);
        
        }else if(isSafeToChangeState()){
            
            changeState(nextState);
        }
        
    }

    void U4DPlayerStateManager::changeState(U4DPlayerStateInterface *uState){
        
        if(currentState!=uState){
            
            //remove animation
            player->animationManager->removeCurrentPlayingAnimation();
            
            //pause collision with foot
            
            player->foot->kineticAction->pauseCollisionBehavior();
            
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
            player->animationManager->playAnimation();
            
            changeStateRequest=false;
            
//            U4DLogger *logger=U4DLogger::sharedInstance();
//            logger->log("U4DPlayer %s Current State %s",player->getName().c_str(),currentState->name.c_str());
            
        }
        
    }

    bool U4DPlayerStateManager::isSafeToChangeState(){
        
        if (currentState!=NULL) {
            return currentState->isSafeToChangeState(player);
        }else{
            return true;
        }
        
    }

    void U4DPlayerStateManager::safeChangeState(U4DPlayerStateInterface *uState){
        
        changeStateRequest=true;
        nextState=uState;
        
    }

    bool U4DPlayerStateManager::handleMessage(Message &uMsg){
    
        if(currentState!=nullptr){
            return currentState->handleMessage(player, uMsg);
        }else{
            return false;
        }
    
    }

    U4DPlayerStateInterface *U4DPlayerStateManager::getCurrentState(){
        
        return currentState;
        
    }

    U4DPlayerStateInterface *U4DPlayerStateManager::getPreviousState(){
        
        return previousState;
        
    }

    std::string U4DPlayerStateManager::getCurrentStateName(){
        return currentState->name;
    }
}
