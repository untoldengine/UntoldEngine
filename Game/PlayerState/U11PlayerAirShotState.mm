//
//  U11PlayerAirShotState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerAirShotState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerIdleState.h"
#include "UserCommonProtocols.h"

U11PlayerAirShotState* U11PlayerAirShotState::instance=0;

U11PlayerAirShotState::U11PlayerAirShotState(){
    
}

U11PlayerAirShotState::~U11PlayerAirShotState(){
    
}

U11PlayerAirShotState* U11PlayerAirShotState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerAirShotState();
    }
    
    return instance;
    
}

void U11PlayerAirShotState::enter(U11Player *uPlayer){
    
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
}

void U11PlayerAirShotState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToAir(ballAirShotSpeed, direction,dt);
        
        uPlayer->removeKineticForces();
        
        U11PlayerIdleState *idleState=U11PlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }
    
    uPlayer->seekBall();
    
}

void U11PlayerAirShotState::exit(U11Player *uPlayer){
    
}

bool U11PlayerAirShotState::isSafeToChangeState(U11Player *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}

bool U11PlayerAirShotState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
