//
//  SoccerPlayerReverseKickState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/24/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerReverseKickState.h"
#include "SoccerPlayerDribbleState.h"



SoccerPlayerReverseKickState* SoccerPlayerReverseKickState::instance=0;

SoccerPlayerReverseKickState::SoccerPlayerReverseKickState(){
    
}

SoccerPlayerReverseKickState::~SoccerPlayerReverseKickState(){
    
}

SoccerPlayerReverseKickState* SoccerPlayerReverseKickState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerReverseKickState();
    }
    
    return instance;
    
}

void SoccerPlayerReverseKickState::enter(SoccerPlayer *uPlayer){
    
    //set the control ball animation
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getReverseBallWithRightFootAnimation());
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        
    }else{
        
        uPlayer->setNextAnimationToPlay(uPlayer->getReverseBallWithLeftFootAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    
}

void SoccerPlayerReverseKickState::execute(SoccerPlayer *uPlayer, double dt){
    
    SoccerBall *ball=uPlayer->getBallEntity();
    
    if (ball->getVelocity().magnitude()>8.0) {
        uPlayer->decelerateBall(0.5, dt);
    }
    
    if (uPlayer->getActiveExtremityCollidedWithBall() && uPlayer->getAnimationCurrentKeyframe()>=1) {
        
        U4DEngine::U4DVector3n directionToKick=uPlayer->getJoystickDirection();
        
        directionToKick.z=-directionToKick.y;
        
        directionToKick.y=0;
        
        SoccerBall *ball=uPlayer->getBallEntity();
        
        ball->kickBallToGround(25.0, directionToKick, dt);
        
        uPlayer->setDirectionReversal(false);
        uPlayer->changeState(SoccerPlayerDribbleState::sharedInstance());
        
    }
    
}

void SoccerPlayerReverseKickState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerReverseKickState::isSafeToChangeState(SoccerPlayer *uPlayer){
    
    //check if animation can be interrupted or if the animation has stopped
    if (uPlayer->getCurrentPlayingAnimation()->getIsAllowedToBeInterrupted()==true || !uPlayer->getCurrentPlayingAnimation()->getAnimationIsPlaying()) {
        
        return true;
    }
    
    return false;
}
