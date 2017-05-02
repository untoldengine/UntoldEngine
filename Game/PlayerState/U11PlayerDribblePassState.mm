//
//  U11PlayerDribblePassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerDribblePassState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerGroundPassState.h"

U11PlayerDribblePassState* U11PlayerDribblePassState::instance=0;

U11PlayerDribblePassState::U11PlayerDribblePassState(){
    
}

U11PlayerDribblePassState::~U11PlayerDribblePassState(){
    
}

U11PlayerDribblePassState* U11PlayerDribblePassState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerDribblePassState();
    }
    
    return instance;
    
}

void U11PlayerDribblePassState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
}

void U11PlayerDribblePassState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->seekBall();
    
    
    //has the player reached the ball
    if (uPlayer->distanceToBall()>1.5) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->changeState(U11PlayerGroundPassState::sharedInstance());
        
    }
    
}

void U11PlayerDribblePassState::exit(U11Player *uPlayer){
    
}

bool U11PlayerDribblePassState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerDribblePassState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
}
