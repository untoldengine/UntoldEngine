//
//  U11PlayerDefendState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDefendState.h"
#include "U11PlayerRunToDefendState.h"
#include "U11PlayerDefenseFormationState.h"


U11PlayerDefendState* U11PlayerDefendState::instance=0;

U11PlayerDefendState::U11PlayerDefendState(){
    
}

U11PlayerDefendState::~U11PlayerDefendState(){
    
}

U11PlayerDefendState* U11PlayerDefendState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerDefendState();
    }
    
    return instance;
    
}

void U11PlayerDefendState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getIdleAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    
}

void U11PlayerDefendState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->seekBall();
    
}

void U11PlayerDefendState::exit(U11Player *uPlayer){
    
}

bool U11PlayerDefendState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerDefendState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
              
        case msgRunToDefend:
            
            if (!uPlayer->hasReachedPosition(uPlayer->getDefendingPosition(),withinDefenseDistance)) {
                uPlayer->changeState(U11PlayerRunToDefendState::sharedInstance());
            }
            
            break;
            
        case msgRunToDefendingFormation:
            
            if (!uPlayer->hasReachedPosition(uPlayer->getFormationPosition(),withinDefenseDistance)) {
                uPlayer->changeState(U11PlayerDefenseFormationState::sharedInstance());
                
            }
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
