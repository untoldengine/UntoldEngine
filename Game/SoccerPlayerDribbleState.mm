//
//  SoccerPlayerDribbleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerDribbleState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerGroundPassState.h"
#include "SoccerBall.h"

SoccerPlayerDribbleState* SoccerPlayerDribbleState::instance=0;

SoccerPlayerDribbleState::SoccerPlayerDribbleState(){
    
}

SoccerPlayerDribbleState::~SoccerPlayerDribbleState(){
    
}

SoccerPlayerDribbleState* SoccerPlayerDribbleState::sharedInstance(){
    
    if (instance==0) {
        instance=new SoccerPlayerDribbleState();
    }
    
    return instance;
    
}

void SoccerPlayerDribbleState::enter(SoccerPlayer *uPlayer){
    
    //set dribble animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayNextAnimationContinuously(true);
    uPlayer->setPlayBlendedAnimation(true);
    
    
}

void SoccerPlayerDribbleState::execute(SoccerPlayer *uPlayer, double dt){
    
    //check if player should pass
    if (uPlayer->getButtonAPressed()) {
        
        uPlayer->setFlagToPassBall(true);
        
    }
    
    U4DEngine::U4DVector3n directionToKick=uPlayer->getPlayerHeading();
    
    //if the joystick is active, set the new direction of the kick
    if (uPlayer->getJoystickActive()) {
        
        directionToKick=uPlayer->getJoystickDirection();
        directionToKick.z=-directionToKick.y;
        
        directionToKick.y=0;
    }
    
    //check if player should pass
    if (uPlayer->getFlagToPassBall()) {
        
        //ball->removeKineticForces();
        
        SoccerPlayerGroundPassState *groundPassState=SoccerPlayerGroundPassState::sharedInstance();
        
        uPlayer->changeState(groundPassState);
        
    }
    
    //keep dribbling
    if (uPlayer->getFootCollidedWithBall()) {
        
        uPlayer->kickBallToGround(20.0, directionToKick,dt);
    
    }
    
    //chase the ball
    uPlayer->applyForceToPlayer(10.0, dt);
    
    uPlayer->trackBall();
}

void SoccerPlayerDribbleState::exit(SoccerPlayer *uPlayer){
    
}
