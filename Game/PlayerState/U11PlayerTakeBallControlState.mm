//
//  U11PlayerTakeBallControlState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/19/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerTakeBallControlState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerGroundPassState.h"
#include "U11PlayerGroundShotState.h"
#include "U11PlayerAirShotState.h"
#include "U11PlayerReverseKickState.h"
#include "U11PlayerRunPassState.h"
#include "U11BallGroundState.h"
#include "U11Ball.h"
#include "U11Team.h"
#include "UserCommonProtocols.h"

U11PlayerTakeBallControlState* U11PlayerTakeBallControlState::instance=0;

U11PlayerTakeBallControlState::U11PlayerTakeBallControlState(){
    
}

U11PlayerTakeBallControlState::~U11PlayerTakeBallControlState(){
    
}

U11PlayerTakeBallControlState* U11PlayerTakeBallControlState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerTakeBallControlState();
    }
    
    return instance;
    
}

void U11PlayerTakeBallControlState::enter(U11Player *uPlayer){
    
    //set the control ball animation
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getHaltBallWithRightFootAnimation());
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
    }else{
     
        uPlayer->setNextAnimationToPlay(uPlayer->getHaltBallWithLeftFootAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    
    //set as the controlling player
    uPlayer->getTeam()->setControllingPlayer(uPlayer);
    
}

void U11PlayerTakeBallControlState::execute(U11Player *uPlayer, double dt){
    
    U11Ball *ball=uPlayer->getSoccerBall();
    
    //stop ball motion if the feet collide with the ball and if it matches a keyframe 
    if (uPlayer->getActiveExtremityCollidedWithBall() && uPlayer->getAnimationCurrentKeyframe()>=3) {
        
        ball->removeKineticForces();
        
        ball->removeAllVelocities();
        
        ball->changeState(U11BallGroundState::sharedInstance());
        
        
    }else{
        
        if (ball->getVelocity().magnitude()>ballMaxSpeedMagnitude) {
            uPlayer->decelerateBall(ballDeceleration, dt);
        }
        
    }
    
    
    if (uPlayer->getButtonAPressed()) {
    
        if (uPlayer->hasReachedTheBall()) {
            
            uPlayer->changeState(U11PlayerGroundPassState::sharedInstance());
            
        }else{
            uPlayer->changeState(U11PlayerRunPassState::sharedInstance());
        }
        
    
    }
    
    //check if player should shoot
    if (uPlayer->getButtonBPressed()) {
        
        uPlayer->changeState(U11PlayerAirShotState::sharedInstance());
        
    }
    
    //if joystick is active go into dribble state
    if (uPlayer->getJoystickActive()) {
        
        //check if the joystick changed directions
        
        if ((uPlayer->getDirectionReversal())) {
            
            uPlayer->changeState(U11PlayerReverseKickState::sharedInstance());
            
        }
    
        uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
        
    }
    
}

void U11PlayerTakeBallControlState::exit(U11Player *uPlayer){
    
}

bool U11PlayerTakeBallControlState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerTakeBallControlState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
