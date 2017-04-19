//
//  U11PlayerFormationPositionState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerFormationPositionState.h"
#include "U11PlayerIdleState.h"

U11PlayerFormationPositionState* U11PlayerFormationPositionState::instance=0;

U11PlayerFormationPositionState::U11PlayerFormationPositionState(){
    
}

U11PlayerFormationPositionState::~U11PlayerFormationPositionState(){
    
}

U11PlayerFormationPositionState* U11PlayerFormationPositionState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerFormationPositionState();
    }
    
    return instance;
    
}

void U11PlayerFormationPositionState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerFormationPositionState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DPoint3n homePosition=uPlayer->getFormationPosition();
    
    uPlayer->seekPosition(homePosition);
    
    if (!uPlayer->hasReachedPosition(homePosition, withinFormationDistance)) {
        
        //make the player run
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
        
        uPlayer->changeState(U11PlayerIdleState::sharedInstance());
        
    }
    
    
}

void U11PlayerFormationPositionState::exit(U11Player *uPlayer){
    
}

bool U11PlayerFormationPositionState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerFormationPositionState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    
    return false;
    
}
