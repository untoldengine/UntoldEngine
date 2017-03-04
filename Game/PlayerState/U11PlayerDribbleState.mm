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
#include "U11PlayerGroundShotState.h"
#include "U11PlayerReverseKickState.h"
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
    
}

void U11PlayerDribbleState::execute(U11Player *uPlayer, double dt){
    
    U4DEngine::U4DVector3n directionToKick=uPlayer->getPlayerHeading();
    
    //check if player should pass
    if (uPlayer->getButtonAPressed()) {
        
        uPlayer->changeState(U11PlayerGroundPassState::sharedInstance());
        
    }
    
    //check if player should shoot
    if (uPlayer->getButtonBPressed()) {
        
        uPlayer->changeState(U11PlayerGroundShotState::sharedInstance());
        
    }

    
    //if the joystick is active, set the new direction of the kick
    if (uPlayer->getJoystickActive()) {
        
        //check if the joystick changed directions
        
        if (uPlayer->getDirectionReversal()) {
            
            uPlayer->changeState(U11PlayerReverseKickState::sharedInstance());
            
        }
        
        directionToKick=uPlayer->getJoystickDirection();
        directionToKick.z=-directionToKick.y;
        
        directionToKick.y=0;
        
    }else{
        
        uPlayer->changeState(U11PlayerChaseBallState::sharedInstance());
    }
    
    //keep dribbling
    if (uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()) {
        
        uPlayer->kickBallToGround(ballRollingSpeed, directionToKick,dt);
    
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
