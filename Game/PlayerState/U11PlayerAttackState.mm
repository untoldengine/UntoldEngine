//
//  U11PlayerAttackState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerAttackState.h"
#include "U11PlayerReceiveBallState.h"
#include "U11PlayerAttackFormationState.h"
#include "U11PlayerSupportState.h"
#include "U11PlayerRunToSupportState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerDefendState.h"
#include "U11PlayerDefenseFormationState.h"
#include "U11PlayerRunToStealState.h"
#include "U11PlayerRunPassState.h"
#include "U11PlayerAirShotState.h"
#include "U11PlayerReverseKickState.h"
#include "U11PlayerDribbleState.h"
#include "U11MessageDispatcher.h"
#include "UserCommonProtocols.h"

U11PlayerAttackState* U11PlayerAttackState::instance=0;

U11PlayerAttackState::U11PlayerAttackState(){
    
}

U11PlayerAttackState::~U11PlayerAttackState(){
    
}

U11PlayerAttackState* U11PlayerAttackState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerAttackState();
    }
    
    return instance;
    
}

void U11PlayerAttackState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getIdleAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    
    uPlayer->removeKineticForces();
    uPlayer->removeAllVelocities();
    
}

void U11PlayerAttackState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->seekBall();
    
}

void U11PlayerAttackState::exit(U11Player *uPlayer){
    
}

bool U11PlayerAttackState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerAttackState::handleMessage(U11Player *uPlayer, Message &uMsg){

    
    switch (uMsg.msg) {
            
        case msgReceiveBall:
            
            uPlayer->changeState(U11PlayerReceiveBallState::sharedInstance());
            
            break;
            
        case msgRunToAttackFormation:
            
            uPlayer->changeState(U11PlayerAttackFormationState::sharedInstance());
            
            break;
            
        case msgSupportPlayer:
            
            uPlayer->changeState(U11PlayerSupportState::sharedInstance());
        
            break;
            
        case msgPassToMe:
            
            
            break;
        
        case msgRunToSupport:
            
            uPlayer->changeState(U11PlayerRunToSupportState::sharedInstance());
            
            break;
            
        case msgButtonAPressed:
        {
            int passBallSpeed=*((int*)uMsg.extraInfo);
            
            uPlayer->setBallKickSpeed(passBallSpeed);
            
            uPlayer->changeState(U11PlayerRunPassState::sharedInstance());
        }
            break;
            
        case msgButtonBPressed:
        {
            int passBallSpeed=*((int*)uMsg.extraInfo);
            
            uPlayer->setBallKickSpeed(passBallSpeed);
            
            uPlayer->changeState(U11PlayerAirShotState::sharedInstance());
        }
            break;
            
        case msgJoystickActive:
        {
            JoystickMessageData joystickMessageData=*((JoystickMessageData*)uMsg.extraInfo);
            
            if (joystickMessageData.changedDirection) {
                
                uPlayer->changeState(U11PlayerReverseKickState::sharedInstance());
                
            }
            
            uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
            
            
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}
