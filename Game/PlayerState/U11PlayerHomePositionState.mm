//
//  U11PlayerHomePositionState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/13/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerHomePositionState.h"
#include "U11PlayerIdleState.h"

U11PlayerHomePositionState* U11PlayerHomePositionState::instance=0;

U11PlayerHomePositionState::U11PlayerHomePositionState(){
    
}

U11PlayerHomePositionState::~U11PlayerHomePositionState(){
    
}

U11PlayerHomePositionState* U11PlayerHomePositionState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerHomePositionState();
    }
    
    return instance;
    
}

void U11PlayerHomePositionState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerHomePositionState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DPoint3n homePosition=uPlayer->getFormationPosition();
    
    uPlayer->seekPosition(homePosition);
    
    if (!uPlayer->hasReachedPosition(homePosition, withinHomeDistance)) {
        
        //make the player run
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
        
        uPlayer->changeState(U11PlayerIdleState::sharedInstance());
        
    }
    
    
}

void U11PlayerHomePositionState::exit(U11Player *uPlayer){
    
}

bool U11PlayerHomePositionState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerHomePositionState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    
    return false;
    
}
