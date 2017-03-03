//
//  SoccerPlayerAirShotState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/27/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerAirShotState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerIdleState.h"
#include "UserCommonProtocols.h"

SoccerPlayerAirShotState* SoccerPlayerAirShotState::instance=0;

SoccerPlayerAirShotState::SoccerPlayerAirShotState(){
    
}

SoccerPlayerAirShotState::~SoccerPlayerAirShotState(){
    
}

SoccerPlayerAirShotState* SoccerPlayerAirShotState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerAirShotState();
    }
    
    return instance;
    
}

void SoccerPlayerAirShotState::enter(SoccerPlayer *uPlayer){
    
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

void SoccerPlayerAirShotState::execute(SoccerPlayer *uPlayer, double dt){
    
    //track the ball
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToAir(ballAirShotSpeed, direction,dt);
        
        uPlayer->removeKineticForces();
        
        SoccerPlayerIdleState *idleState=SoccerPlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }
    
    uPlayer->trackBall();
    
}

void SoccerPlayerAirShotState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerAirShotState::isSafeToChangeState(SoccerPlayer *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}
