//
//  SoccerPlayerGroundPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerGroundPassState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerIdleState.h"
#include "UserCommonProtocols.h"

SoccerPlayerGroundPassState* SoccerPlayerGroundPassState::instance=0;

SoccerPlayerGroundPassState::SoccerPlayerGroundPassState(){
    
}

SoccerPlayerGroundPassState::~SoccerPlayerGroundPassState(){
    
}

SoccerPlayerGroundPassState* SoccerPlayerGroundPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerGroundPassState();
    }
    
    return instance;
    
}

void SoccerPlayerGroundPassState::enter(SoccerPlayer *uPlayer){
    
    //set the ground pass animation
    
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightFootSidePassAnimation());
        
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftFootSidePassAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
        
    }
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setPlayBlendedAnimation(true);
    
}

void SoccerPlayerGroundPassState::execute(SoccerPlayer *uPlayer, double dt){
    
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(ballPassingSpeed, direction,dt);
        
        uPlayer->removeKineticForces();
        
        SoccerPlayerIdleState *idleState=SoccerPlayerIdleState::sharedInstance();
        
        uPlayer->changeState(idleState);
    }

    uPlayer->seekBall();
    
}

void SoccerPlayerGroundPassState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerGroundPassState::isSafeToChangeState(SoccerPlayer *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}
