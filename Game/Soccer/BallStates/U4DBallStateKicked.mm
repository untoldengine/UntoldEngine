//
//  U4DBallStateKicked.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateKicked.h"
#include "U4DBallStateDecelerate.h"

namespace U4DEngine {

U4DBallStateKicked* U4DBallStateKicked::instance=0;

U4DBallStateKicked::U4DBallStateKicked(){
    name="kicked";
}

U4DBallStateKicked::~U4DBallStateKicked(){
    
}

U4DBallStateKicked* U4DBallStateKicked::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DBallStateKicked();
    }
    
    return instance;
    
}

void U4DBallStateKicked::enter(U4DBall *uBall){
    
    uBall->obstacleCollisionTimer->setPause(false);
    
}

void U4DBallStateKicked::execute(U4DBall *uBall, double dt){
    
    U4DVector3n dir=uBall->kickDirection*uBall->kickMagnitude;
    
    uBall->applyVelocity(dir, dt);
    
    if(!uBall->kineticAction->getModelHasCollided()){
        uBall->changeState(U4DBallStateDecelerate::sharedInstance());
    }
     
}

void U4DBallStateKicked::exit(U4DBall *uBall){
    
    
    
}

bool U4DBallStateKicked::isSafeToChangeState(U4DBall *uBall){
    
    return true;
}

bool U4DBallStateKicked::handleMessage(U4DBall *uBall, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
