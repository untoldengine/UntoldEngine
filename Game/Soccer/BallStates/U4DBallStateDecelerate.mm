//
//  U4DBallStateDecelerate.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateDecelerate.h"

namespace U4DEngine {

U4DBallStateDecelerate* U4DBallStateDecelerate::instance=0;

U4DBallStateDecelerate::U4DBallStateDecelerate(){
    name="decelerate";
}

U4DBallStateDecelerate::~U4DBallStateDecelerate(){
    
}

U4DBallStateDecelerate* U4DBallStateDecelerate::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DBallStateDecelerate();
    }
    
    return instance;
    
}

void U4DBallStateDecelerate::enter(U4DBall *uBall){
    
    
}

void U4DBallStateDecelerate::execute(U4DBall *uBall, double dt){
    
    //remove all velocities from the character
    uBall->decelerate(dt);
    
}

void U4DBallStateDecelerate::exit(U4DBall *uBall){
    
    uBall->obstacleCollisionTimer->setPause(true);
    
}

bool U4DBallStateDecelerate::isSafeToChangeState(U4DBall *uBall){
    
    return true;
}

bool U4DBallStateDecelerate::handleMessage(U4DBall *uBall, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
