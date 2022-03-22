//
//  U4DBallStateLob.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateLob.h"
#include "U4DBallStateFalling.h"

namespace U4DEngine {

U4DBallStateLob* U4DBallStateLob::instance=0;

U4DBallStateLob::U4DBallStateLob(){
    name="lob";
}

U4DBallStateLob::~U4DBallStateLob(){
    
}

U4DBallStateLob* U4DBallStateLob::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DBallStateLob();
    }
    
    return instance;
    
}

void U4DBallStateLob::enter(U4DBall *uBall){
    
    maxHeight=uBall->getAbsolutePosition().y;
    
}

void U4DBallStateLob::execute(U4DBall *uBall, double dt){
    
    U4DVector3n dir=uBall->kickDirection*uBall->kickMagnitude;
    dir.x*=0.5;
    dir.z*=0.5;
    dir.y=10.0;
    
    uBall->applyVelocity(dir, dt);
    
    if((uBall->getAbsolutePosition().y - maxHeight)>3.0){
        uBall->changeState(U4DBallStateFalling::sharedInstance());
    }
}

void U4DBallStateLob::exit(U4DBall *uBall){
    
}

bool U4DBallStateLob::isSafeToChangeState(U4DBall *uBall){
    
    return true;
}

bool U4DBallStateLob::handleMessage(U4DBall *uBall, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
