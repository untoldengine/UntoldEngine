//
//  U11PlayerRunToStealState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/29/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRunToStealState.h"
#include "U11PlayerMarkingState.h"
#include "U11PlayerInterceptPassState.h"

U11PlayerRunToStealState* U11PlayerRunToStealState::instance=0;

U11PlayerRunToStealState::U11PlayerRunToStealState(){
    
}

U11PlayerRunToStealState::~U11PlayerRunToStealState(){
    
}

U11PlayerRunToStealState* U11PlayerRunToStealState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRunToStealState();
    }
    
    return instance;
    
}

void U11PlayerRunToStealState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    
}

void U11PlayerRunToStealState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->seekBall();
    
    //has the player reached the ball
    if (uPlayer->distanceToBall()>markingDistanceToBall) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
            
        uPlayer->changeState(U11PlayerMarkingState::sharedInstance());
        
        
    }
   
}

void U11PlayerRunToStealState::exit(U11Player *uPlayer){
    
}

bool U11PlayerRunToStealState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRunToStealState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgInterceptPass:
            
            uPlayer->changeState(U11PlayerInterceptPassState::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
