//
//  U11PlayerChaseBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/17/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerChaseBallState.h"
#include "U11PlayerTakeBallControlState.h"
#include "UserCommonProtocols.h"

U11PlayerChaseBallState* U11PlayerChaseBallState::instance=0;

U11PlayerChaseBallState::U11PlayerChaseBallState(){
    
}

U11PlayerChaseBallState::~U11PlayerChaseBallState(){
    
}

U11PlayerChaseBallState* U11PlayerChaseBallState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerChaseBallState();
    }
    
    return instance;
}

void U11PlayerChaseBallState::enter(U11Player *uPlayer){
 
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
}

void U11PlayerChaseBallState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->seekBall();
    
    
    //has the player reached the ball
    if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
        
    }else{
        
        uPlayer->removeKineticForces();
        
        U11PlayerStateInterface *takeBallControlState=U11PlayerTakeBallControlState::sharedInstance();
        
        uPlayer->changeState(takeBallControlState);
        
        
    }
     
}

void U11PlayerChaseBallState::exit(U11Player *uPlayer){
    
}

bool U11PlayerChaseBallState::isSafeToChangeState(U11Player *uPlayer){
    return true;
}

bool U11PlayerChaseBallState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
