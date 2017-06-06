//
//  U11PlayerDefendPositionState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDefendPositionState.h"
#include "U11PlayerDefendState.h"
#include "U11PlayerInterceptState.h"

U11PlayerDefendPositionState* U11PlayerDefendPositionState::instance=0;

U11PlayerDefendPositionState::U11PlayerDefendPositionState(){
    
}

U11PlayerDefendPositionState::~U11PlayerDefendPositionState(){
    
}

U11PlayerDefendPositionState* U11PlayerDefendPositionState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerDefendPositionState();
    }
    
    return instance;
    
}

void U11PlayerDefendPositionState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerDefendPositionState::execute(U11Player *uPlayer, double dt){
    
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

void U11PlayerDefendPositionState::exit(U11Player *uPlayer){
    
}

bool U11PlayerDefendPositionState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerDefendPositionState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgIntercept:
            
            uPlayer->changeState(U11PlayerInterceptState::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
