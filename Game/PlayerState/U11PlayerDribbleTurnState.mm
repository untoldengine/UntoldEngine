//
//  U11PlayerDribbleTurn.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/12/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDribbleTurnState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerGroundPassState.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerDribblePassState.h"
#include "U11PlayerGroundShotState.h"

U11PlayerDribbleTurnState* U11PlayerDribbleTurnState::instance=0;

U11PlayerDribbleTurnState::U11PlayerDribbleTurnState(){
    
}

U11PlayerDribbleTurnState::~U11PlayerDribbleTurnState(){
    
}

U11PlayerDribbleTurnState* U11PlayerDribbleTurnState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerDribbleTurnState();
    }
    
    return instance;
    
}

void U11PlayerDribbleTurnState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRightDribbleAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerDribbleTurnState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->computePlayerDribblingSpeed();
    
    //keep dribbling
    if (uPlayer->getRightFootCollidedWithBall() || uPlayer->getLeftFootCollidedWithBall()) {
    
            U4DEngine::U4DVector3n dribbleDirection=uPlayer->getBallKickDirection();
            U4DEngine::U4DVector3n playerHeading=uPlayer->getPlayerHeading();
            
            playerHeading.y=0.0;
            
            dribbleDirection.normalize();
            playerHeading.normalize();
            
            //get the angle
            float angle=playerHeading.angle(dribbleDirection);
            
            //divide the angle by 4 for smoothness
            angle/=4.0;
            
            //get the axis of rotation
            
            U4DEngine::U4DVector3n zAxis=playerHeading.cross(dribbleDirection);
            
            //half the dribble direction
            dribbleDirection=playerHeading.rotateVectorAboutAngleAndAxis(angle, zAxis);
            
            uPlayer->kickBallToGround(ballRollingSpeed, dribbleDirection,dt);
            
            
            
        if (uPlayer->isHeadingWithinRange()==true) {
            
            
            uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
            
        }
    
    }
    
    //chase the ball
    uPlayer->applyForceToPlayer(uPlayer->getPlayerDribblingSpeed(), dt);
    
    uPlayer->seekBall();
    
    
}

void U11PlayerDribbleTurnState::exit(U11Player *uPlayer){
    
}

bool U11PlayerDribbleTurnState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerDribbleTurnState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgButtonAPressed:
            
            uPlayer->changeState(U11PlayerDribblePassState::sharedInstance());
            
            return true;
            
            break;
            
        case msgButtonBPressed:
            
            uPlayer->changeState(U11PlayerGroundShotState::sharedInstance());
            
            return true;
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
