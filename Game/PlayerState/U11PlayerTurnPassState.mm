//
//  U11PlayerTurnPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/26/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerTurnPassState.h"
#include "U11PlayerRunPassState.h"


U11PlayerTurnPassState* U11PlayerTurnPassState::instance=0;

U11PlayerTurnPassState::U11PlayerTurnPassState(){
    
}

U11PlayerTurnPassState::~U11PlayerTurnPassState(){
    
}

U11PlayerTurnPassState* U11PlayerTurnPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerTurnPassState();
    }
    
    return instance;
    
}

void U11PlayerTurnPassState::enter(U11Player *uPlayer){
    
    if (uPlayer->isBallOnRightSidePlane()) {
        
        uPlayer->setNextAnimationToPlay(uPlayer->getRightCarryAnimation());
        uPlayer->setActiveExtremity(uPlayer->getRightFoot());
        
    }else{
    
        uPlayer->setNextAnimationToPlay(uPlayer->getLeftCarryAnimation());
        uPlayer->setActiveExtremity(uPlayer->getLeftFoot());
        
    }
    
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    
}

void U11PlayerTurnPassState::execute(U11Player *uPlayer, double dt){
    
    if (uPlayer->getActiveExtremityCollidedWithBall()) {
        
        if (uPlayer->getAnimationCurrentKeyframe()==3) {
            U4DEngine::U4DVector3n dribbleDirection=uPlayer->getBallKickDirection();
            U4DEngine::U4DVector3n playerHeading=uPlayer->getPlayerHeading();
            
            playerHeading.y=0.0;
            
            dribbleDirection.normalize();
            playerHeading.normalize();
            
            //get the angle
            float angle=playerHeading.angle(dribbleDirection);
            
            //get the axis of rotation
            
            U4DEngine::U4DVector3n zAxis=playerHeading.cross(dribbleDirection);
            
            //half the dribble direction
            dribbleDirection=playerHeading.rotateVectorAboutAngleAndAxis(angle, zAxis);
            
            uPlayer->kickBallToGround(10, dribbleDirection,dt);
            
        }
    }
    
    if (!uPlayer->getCurrentPlayingAnimation()->isAnimationPlaying()) {
        
        uPlayer->setBallKickSpeed(50.0);
        
        uPlayer->changeState(U11PlayerRunPassState::sharedInstance());
    }
    
}

void U11PlayerTurnPassState::exit(U11Player *uPlayer){
    
}

bool U11PlayerTurnPassState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerTurnPassState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
}
