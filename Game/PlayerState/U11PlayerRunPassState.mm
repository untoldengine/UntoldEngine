//
//  U11PlayerRunPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/12/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRunPassState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerGroundPassState.h"

U11PlayerRunPassState* U11PlayerRunPassState::instance=0;

U11PlayerRunPassState::U11PlayerRunPassState(){
    
}

U11PlayerRunPassState::~U11PlayerRunPassState(){
    
}

U11PlayerRunPassState* U11PlayerRunPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRunPassState();
    }
    
    return instance;
    
}

void U11PlayerRunPassState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerRunPassState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->seekBall();
    
    
    //has the player reached the ball
    if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(10.0, dt);
        
        
    }else{
        
        uPlayer->changeState(U11PlayerGroundPassState::sharedInstance());
        
    }
    
}

void U11PlayerRunPassState::exit(U11Player *uPlayer){
    
}

bool U11PlayerRunPassState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRunPassState::handleMessage(U11Player *uPlayer, Message &uMsg){
    

    return false;
}
