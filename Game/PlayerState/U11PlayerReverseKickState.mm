//
//  U11PlayerReverseKickState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/24/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerReverseKickState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerRunToReverseKickState.h"
#include "UserCommonProtocols.h"

U11PlayerReverseKickState* U11PlayerReverseKickState::instance=0;

U11PlayerReverseKickState::U11PlayerReverseKickState(){
    
}

U11PlayerReverseKickState::~U11PlayerReverseKickState(){
    
}

U11PlayerReverseKickState* U11PlayerReverseKickState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerReverseKickState();
    }
    
    return instance;
    
}

void U11PlayerReverseKickState::enter(U11Player *uPlayer){
    
    //set the control ball animation
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightReverseKickAnimation());
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftReverseKickAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    
}

void U11PlayerReverseKickState::execute(U11Player *uPlayer, double dt){
    
    U11Ball *ball=uPlayer->getSoccerBall();
    
    ball->removeKineticForces();
    
    ball->removeAllVelocities();
    
    uPlayer->removeAllVelocities();
    
    uPlayer->removeKineticForces();
    
    if (ball->getVelocity().magnitude()>ballMaxSpeed) {
        uPlayer->decelerateBall(ballDeceleration, dt);
    }
    
    if (uPlayer->getActiveExtremityCollidedWithBall() && uPlayer->getAnimationCurrentKeyframe()>=3) {
        
        ball->kickBallToGround(ballReverseRolling, uPlayer->getBallKickDirection(), dt);
        
        uPlayer->setDirectionReversal(false);
        uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
        
    }
    
}

void U11PlayerReverseKickState::exit(U11Player *uPlayer){
    
}

bool U11PlayerReverseKickState::isSafeToChangeState(U11Player *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}

bool U11PlayerReverseKickState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
