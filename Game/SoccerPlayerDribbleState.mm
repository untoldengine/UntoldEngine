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
#include "SoccerPlayerTakeBallControlState.h"
#include "SoccerPlayerGroundShotState.h"
#include "SoccerPlayerReverseKickState.h"
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
    
    U4DEngine::U4DVector3n directionToKick=uPlayer->getPlayerHeading();
    
    //check if player should pass
    if (uPlayer->getButtonAPressed()) {
        
        uPlayer->changeState(SoccerPlayerGroundPassState::sharedInstance());
        
    }
    
    //check if player should shoot
    if (uPlayer->getButtonBPressed()) {
        
        uPlayer->changeState(SoccerPlayerGroundShotState::sharedInstance());
        
    }

    
    //if the joystick is active, set the new direction of the kick
    if (uPlayer->getJoystickActive()) {
        
        //check if the joystick changed directions
        
        if (uPlayer->getDirectionReversal()) {
            
            uPlayer->changeState(SoccerPlayerReverseKickState::sharedInstance());
            
        }
        
        directionToKick=uPlayer->getJoystickDirection();
        directionToKick.z=-directionToKick.y;
        
        directionToKick.y=0;
        
    }else{
        
        uPlayer->changeState(SoccerPlayerChaseBallState::sharedInstance());
    }
    
    //keep dribbling
    if (uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()) {
        
        uPlayer->kickBallToGround(23.0, directionToKick,dt);
    
    }
    
    //chase the ball
    uPlayer->applyForceToPlayer(15.0, dt);
    
    uPlayer->trackBall();
}

void SoccerPlayerDribbleState::exit(SoccerPlayer *uPlayer){
    
}

bool SoccerPlayerDribbleState::isSafeToChangeState(SoccerPlayer *uPlayer){
    return true;
}
