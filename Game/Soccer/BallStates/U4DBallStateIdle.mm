//
//  U4DBallStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateIdle.h"

namespace U4DEngine {

U4DBallStateIdle* U4DBallStateIdle::instance=0;

U4DBallStateIdle::U4DBallStateIdle(){
    name="idle";
}

U4DBallStateIdle::~U4DBallStateIdle(){
    
}

U4DBallStateIdle* U4DBallStateIdle::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DBallStateIdle();
    }
    
    return instance;
    
}

void U4DBallStateIdle::enter(U4DBall *uBall){
    
    //remove all velocities from the character
    U4DVector3n zero(0.0,0.0,0.0);

    uBall->kineticAction->setVelocity(zero);
    uBall->kineticAction->setAngularVelocity(zero);
    
    uBall->obstacleCollisionTimer->setPause(false);
}

void U4DBallStateIdle::execute(U4DBall *uBall, double dt){
    
    
}

void U4DBallStateIdle::exit(U4DBall *uBall){
    
    uBall->obstacleCollisionTimer->setPause(true);
    
}

bool U4DBallStateIdle::isSafeToChangeState(U4DBall *uBall){
    
    return true;
}

bool U4DBallStateIdle::handleMessage(U4DBall *uBall, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
