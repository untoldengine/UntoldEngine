//
//  U11PlayerGroundShotState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerGroundShotState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerIdleState.h"
#include "UserCommonProtocols.h"
#include "U11TeamIdleState.h"
#include "U11Team.h"

U11PlayerGroundShotState* U11PlayerGroundShotState::instance=0;

U11PlayerGroundShotState::U11PlayerGroundShotState(){
    
}

U11PlayerGroundShotState::~U11PlayerGroundShotState(){
    
}

U11PlayerGroundShotState* U11PlayerGroundShotState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerGroundShotState();
    }
    
    return instance;
    
}

void U11PlayerGroundShotState::enter(U11Player *uPlayer){
    
    //set the forward kick animation
    
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightFootForwardKickAnimation());
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftFootForwardKickAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
    }
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
    
    uPlayer->getTeam()->changeState(U11TeamIdleState::sharedInstance());
}

void U11PlayerGroundShotState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(uPlayer->getBallKickSpeed(), direction,dt);
        
        uPlayer->removeKineticForces();
        
        U11PlayerIdleState *idleState=U11PlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }
    
    uPlayer->seekBall();
    
}

void U11PlayerGroundShotState::exit(U11Player *uPlayer){
    
}

bool U11PlayerGroundShotState::isSafeToChangeState(U11Player *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}

bool U11PlayerGroundShotState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
