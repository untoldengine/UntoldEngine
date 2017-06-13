//
//  U11PlayerDefendState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDefendState.h"
#include "U11PlayerDefendPositionState.h"
#include "U11PlayerDefenseFormationState.h"
#include "U11PlayerMarkingState.h"
#include "U11PlayerTapToStealState.h"
#include "U11PlayerRunToStealState.h"
#include "U11PlayerInterceptState.h"
#include "U11PlayerApproachOpponent.h"
#include "U11Team.h"


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
    
    uPlayer->removeKineticForces();
    uPlayer->removeAllVelocities();
    
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
                uPlayer->changeState(U11PlayerDefendPositionState::sharedInstance());
            }
            
            break;
            
        case msgRunToDefendingFormation:
            
            if (!uPlayer->hasReachedPosition(uPlayer->getFormationPosition(),withinDefenseDistance)) {
                uPlayer->changeState(U11PlayerDefenseFormationState::sharedInstance());
                
            }
            
            break;
            
        case msgRunToSteal:
            
            uPlayer->changeState(U11PlayerRunToStealState::sharedInstance());
            
            
            break;
            
        case msgIntercept:
            
            uPlayer->changeState(U11PlayerInterceptState::sharedInstance());
            
            break;
            
            
        case msgButtonAPressed:
        {
            //mark
            uPlayer->changeState(U11PlayerMarkingState::sharedInstance());
        }
            break;
            
        case msgButtonBPressed:
        {
            //switch defenders
            U11Team *team=uPlayer->getTeam();
            
            team->setManualDefendingPlayer(true);
            
        }
            break;
            
        case msgJoystickActive:
        {
            uPlayer->changeState(U11PlayerApproachOpponent::sharedInstance());
            
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}
