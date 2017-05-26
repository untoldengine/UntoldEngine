//
//  U11PlayerDribbleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDribbleState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerGroundPassState.h"
#include "U11PlayerTakeBallControlState.h"
#include "U11PlayerAirShotState.h"
#include "U11PlayerRunToReverseKickState.h"
#include "U11PlayerRunPassState.h"
#include "U11PlayerDribblePassState.h"
#include "U11PlayerDribbleTurnState.h"
#include "U11Ball.h"
#include "UserCommonProtocols.h"

U11PlayerDribbleState* U11PlayerDribbleState::instance=0;

U11PlayerDribbleState::U11PlayerDribbleState(){
    
}

U11PlayerDribbleState::~U11PlayerDribbleState(){
    
}

U11PlayerDribbleState* U11PlayerDribbleState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerDribbleState();
    }
    
    return instance;
    
}

void U11PlayerDribbleState::enter(U11Player *uPlayer){
    
    //set dribble animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayNextAnimationContinuously(true);
    uPlayer->setPlayBlendedAnimation(true);
    
    U4DEngine::U4DVector3n directionToKick=uPlayer->getPlayerHeading();
    
    uPlayer->setBallKickDirection(directionToKick);
    
    
}

void U11PlayerDribbleState::execute(U11Player *uPlayer, double dt){
    
    //keep dribbling
    if (uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()) {
        
        uPlayer->kickBallToGround(ballRollingSpeed, uPlayer->getBallKickDirection(),dt);
    
    }
    
    //chase the ball
    uPlayer->applyForceToPlayer(dribblingSpeed, dt);
    
    uPlayer->seekBall();
}

void U11PlayerDribbleState::exit(U11Player *uPlayer){
    
}

bool U11PlayerDribbleState::isSafeToChangeState(U11Player *uPlayer){
    return true;
}

bool U11PlayerDribbleState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgButtonAPressed:
        {
            int passBallSpeed=*((int*)uMsg.extraInfo);
            
            uPlayer->setBallKickSpeed(passBallSpeed);
            
            uPlayer->changeState(U11PlayerDribblePassState::sharedInstance());
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
            
            uPlayer->setJoystickDirection(joystickMessageData.direction);
            
            if (joystickMessageData.changedDirection) {
                
                uPlayer->changeState(U11PlayerRunToReverseKickState::sharedInstance());
                
            }
            
            if (uPlayer->isHeadingWithinRange()==false) {
                
                uPlayer->changeState(U11PlayerDribbleTurnState::sharedInstance());
                
            }

            
            uPlayer->setBallKickDirection(joystickMessageData.direction);
            
            
        }
            break;
        
        case msgJoystickNotActive:
        {
            uPlayer->changeState(U11PlayerChaseBallState::sharedInstance());
        }
            break;
            
        default:
            break;
    }
    
    return false;
}
