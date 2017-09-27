//
//  U11PlayerRunState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerRunState.h"

#include "U11MessageDispatcher.h"
#include "UserCommonProtocols.h"

U11PlayerRunState* U11PlayerRunState::instance=0;

U11PlayerRunState::U11PlayerRunState(){
    
}

U11PlayerRunState::~U11PlayerRunState(){
    
}

U11PlayerRunState* U11PlayerRunState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerRunState();
    }
    
    return instance;
    
}

void U11PlayerRunState::enter(U11Player *uPlayer){
    
    //set the standing animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    
    uPlayer->removeKineticForces();
    uPlayer->removeAllVelocities();
    
}

void U11PlayerRunState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->applyForceToPlayer(chasingSpeed, dt);
    
}

void U11PlayerRunState::exit(U11Player *uPlayer){
    
}

bool U11PlayerRunState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerRunState::handleMessage(U11Player *uPlayer, Message &uMsg){
    

    
    return false;
}
