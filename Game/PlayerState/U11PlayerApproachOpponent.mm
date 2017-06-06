//
//  U11PlayerApproachOpponent.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerApproachOpponent.h"
#include "U11PlayerRecoverState.h"
#include "U11Team.h"
#include "U11PlayerDefendState.h"
#include "U11PlayerMarkingState.h"


U11PlayerApproachOpponent* U11PlayerApproachOpponent::instance=0;

U11PlayerApproachOpponent::U11PlayerApproachOpponent(){
    
}

U11PlayerApproachOpponent::~U11PlayerApproachOpponent(){
    
}

U11PlayerApproachOpponent* U11PlayerApproachOpponent::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerApproachOpponent();
    }
    
    return instance;
    
}

void U11PlayerApproachOpponent::enter(U11Player *uPlayer){
    
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    

}

void U11PlayerApproachOpponent::execute(U11Player *uPlayer, double dt){
    
   uPlayer->applyForceToPlayer(chasingSpeed, dt);
    
}

void U11PlayerApproachOpponent::exit(U11Player *uPlayer){
    
    
}

bool U11PlayerApproachOpponent::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerApproachOpponent::handleMessage(U11Player *uPlayer, Message &uMsg){

    switch (uMsg.msg) {
            
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
            team->scrollPlayerSelectionID();
            
            team->setManualDefendingPlayer(true);
            
        }
            break;
            
        case msgJoystickActive:
        {
            JoystickMessageData joystickMessageData=*((JoystickMessageData*)uMsg.extraInfo);
            
            joystickMessageData.direction.y=uPlayer->getAbsolutePosition().y;
            
            uPlayer->setPlayerHeading(joystickMessageData.direction);
            
            
        }
            break;
            
        case msgJoystickNotActive:
        {
            uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}
