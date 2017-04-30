//
//  U11PlayerRunToDefendState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRunToDefendState.h"
#include "U11PlayerDefendState.h"

U11PlayerRunToDefendState* U11PlayerRunToDefendState::instance=0;

U11PlayerRunToDefendState::U11PlayerRunToDefendState(){
    
}

U11PlayerRunToDefendState::~U11PlayerRunToDefendState(){
    
}

U11PlayerRunToDefendState* U11PlayerRunToDefendState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRunToDefendState();
    }
    
    return instance;
    
}

void U11PlayerRunToDefendState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerRunToDefendState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DPoint3n defenseSupportPosition=uPlayer->getDefendingPosition();
    
    uPlayer->seekPosition(defenseSupportPosition);
    
    
    if (!uPlayer->hasReachedPosition(defenseSupportPosition,withinDefenseDistance)) {
        
        //make the player run
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
            
        uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        
        
    }

}

void U11PlayerRunToDefendState::exit(U11Player *uPlayer){
    
}

bool U11PlayerRunToDefendState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRunToDefendState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
    
}
