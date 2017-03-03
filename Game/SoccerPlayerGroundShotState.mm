//
//  SoccerPlayerGroundShotState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerGroundShotState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerIdleState.h"
#include "UserCommonProtocols.h"

SoccerPlayerGroundShotState* SoccerPlayerGroundShotState::instance=0;

SoccerPlayerGroundShotState::SoccerPlayerGroundShotState(){
    
}

SoccerPlayerGroundShotState::~SoccerPlayerGroundShotState(){
    
}

SoccerPlayerGroundShotState* SoccerPlayerGroundShotState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerGroundShotState();
    }
    
    return instance;
    
}

void SoccerPlayerGroundShotState::enter(SoccerPlayer *uPlayer){
    
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

void SoccerPlayerGroundShotState::execute(SoccerPlayer *uPlayer, double dt){
    
    //track the ball
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(ballGroundShotSpeed, direction,dt);
        
        uPlayer->removeKineticForces();
        
        SoccerPlayerIdleState *idleState=SoccerPlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }
    
    uPlayer->seekBall();
    
}

void SoccerPlayerGroundShotState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerGroundShotState::isSafeToChangeState(SoccerPlayer *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}
