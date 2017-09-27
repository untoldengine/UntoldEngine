//
//  U11PlayerRunToReverseKickState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/15/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRunToReverseKickState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerReverseKickState.h"
#include "U11PlayerDribbleState.h"

U11PlayerRunToReverseKickState* U11PlayerRunToReverseKickState::instance=0;

U11PlayerRunToReverseKickState::U11PlayerRunToReverseKickState(){
    
}

U11PlayerRunToReverseKickState::~U11PlayerRunToReverseKickState(){
    
}

U11PlayerRunToReverseKickState* U11PlayerRunToReverseKickState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRunToReverseKickState();
    }
    
    return instance;
    
}

void U11PlayerRunToReverseKickState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerRunToReverseKickState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->seekBall();
    
    if (uPlayer->distanceToBall()>reverseBallMaximumDistance) {
        
        uPlayer->changeState(U11PlayerDribbleState::sharedInstance());
    
    }else if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
        
    }else{
        
        uPlayer->changeState(U11PlayerReverseKickState::sharedInstance());
        
    }
    
}

void U11PlayerRunToReverseKickState::exit(U11Player *uPlayer){
    
}

bool U11PlayerRunToReverseKickState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRunToReverseKickState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
}
