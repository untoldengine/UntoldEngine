//
//  U11PlayerIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/18/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerIdleState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerReceiveBallState.h"
#include "U11PlayerSupportState.h"
#include "U11PlayerDefendState.h"
#include "U11PlayerDefenseFormationState.h"
#include "U11MessageDispatcher.h"
#include "UserCommonProtocols.h"

U11PlayerIdleState* U11PlayerIdleState::instance=0;

U11PlayerIdleState::U11PlayerIdleState(){
    
}

U11PlayerIdleState::~U11PlayerIdleState(){
    
}

U11PlayerIdleState* U11PlayerIdleState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerIdleState();
    }
    
    return instance;
    
}

void U11PlayerIdleState::enter(U11Player *uPlayer){
    
    //set the standing animation
    uPlayer->setNextAnimationToPlay(uPlayer->getIdleAnimation());
}

void U11PlayerIdleState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->seekBall();
    
}

void U11PlayerIdleState::exit(U11Player *uPlayer){
    
}

bool U11PlayerIdleState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerIdleState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        case msgReceiveBall:
            
            //change state to receive ball
            uPlayer->changeState(U11PlayerReceiveBallState::sharedInstance());
            
            break;
        
        case msgPassToMe:
            
            break;
            
        case msgSupportPlayer:
            
            uPlayer->changeState(U11PlayerSupportState::sharedInstance());
            
            break;
            
        case msgRunToDefend:
            
            uPlayer->changeState(U11PlayerDefendState::sharedInstance());
            
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
