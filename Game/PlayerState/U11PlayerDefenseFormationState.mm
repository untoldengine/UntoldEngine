//
//  U11PlayerFormationSpace.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/24/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDefenseFormationState.h"
#include "U11PlayerDefendState.h"

U11PlayerDefenseFormationState* U11PlayerDefenseFormationState::instance=0;

U11PlayerDefenseFormationState::U11PlayerDefenseFormationState(){
    
}

U11PlayerDefenseFormationState::~U11PlayerDefenseFormationState(){
    
}

U11PlayerDefenseFormationState* U11PlayerDefenseFormationState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerDefenseFormationState();
    }
    
    return instance;
    
}

void U11PlayerDefenseFormationState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerDefenseFormationState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DPoint3n formationPosition=uPlayer->getFormationPosition();
    
    uPlayer->seekPosition(formationPosition);
    
    if (!uPlayer->hasReachedPosition(formationPosition,withinDefenseDistance)) {
        
        //make the player run
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
        
        uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        
    }
    
}

void U11PlayerDefenseFormationState::exit(U11Player *uPlayer){
    
}

bool U11PlayerDefenseFormationState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerDefenseFormationState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
    
}
