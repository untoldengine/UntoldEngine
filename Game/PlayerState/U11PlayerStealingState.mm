//
//  U11PlayerStealingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerStealingState.h"
#include "U11PlayerDefendState.h"

U11PlayerStealingState* U11PlayerStealingState::instance=0;

U11PlayerStealingState::U11PlayerStealingState(){
    
}

U11PlayerStealingState::~U11PlayerStealingState(){
    
}

U11PlayerStealingState* U11PlayerStealingState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerStealingState();
    }
    
    return instance;
    
}

void U11PlayerStealingState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getStealingAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(false);
    uPlayer->setActiveExtremity(uPlayer->getRightFoot());
}

void U11PlayerStealingState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->seekBall();
    
    if(uPlayer->getActiveExtremityCollidedWithBall()){
        
        U4DEngine::U4DVector3n direction=uPlayer->getPlayerHeading();
        
        uPlayer->kickBallToGround(ballStealingSpeed, direction,dt);
    
    }
    
    if (!uPlayer->getCurrentPlayingAnimation()->isAnimationPlaying()) {
        
        uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        
    }
}

void U11PlayerStealingState::exit(U11Player *uPlayer){
    
}

bool U11PlayerStealingState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerStealingState::handleMessage(U11Player *uPlayer, Message &uMsg){

    
    return false;
    
}
