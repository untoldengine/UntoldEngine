//
//  U11PlayerReceiveBallState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerReceiveBallState.h"
#include "U11PlayerTakeBallControlState.h"
#include "U11Team.h"

U11PlayerReceiveBallState* U11PlayerReceiveBallState::instance=0;

U11PlayerReceiveBallState::U11PlayerReceiveBallState(){
    
}

U11PlayerReceiveBallState::~U11PlayerReceiveBallState(){
    
}

U11PlayerReceiveBallState* U11PlayerReceiveBallState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerReceiveBallState();
    }
    
    return instance;
    
}

void U11PlayerReceiveBallState::enter(U11Player *uPlayer){
    
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
    //set as the receiving player
//    uPlayer->getTeam()->setReceivingPlayer(uPlayer);
}

void U11PlayerReceiveBallState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->interseptBall();
    
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

void U11PlayerReceiveBallState::exit(U11Player *uPlayer){
    
}

bool U11PlayerReceiveBallState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerReceiveBallState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
