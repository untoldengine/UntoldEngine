//
//  U4DBallStateDribbling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateDribbling.h"
#include "U4DBallStateDecelerate.h"

namespace U4DEngine {

U4DBallStateDribbling* U4DBallStateDribbling::instance=0;

U4DBallStateDribbling::U4DBallStateDribbling(){
    name="dribbling";
}

U4DBallStateDribbling::~U4DBallStateDribbling(){
    
}

U4DBallStateDribbling* U4DBallStateDribbling::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DBallStateDribbling();
    }
    
    return instance;
    
}

void U4DBallStateDribbling::enter(U4DBall *uBall){
    
    uBall->obstacleCollisionTimer->setPause(false);
    
}

void U4DBallStateDribbling::execute(U4DBall *uBall, double dt){
    
    U4DVector3n dir=uBall->kickDirection*uBall->kickMagnitude;
    
    uBall->applyVelocity(dir, dt);
    //uBall->setViewDirection(dir);
    if(!uBall->kineticAction->getModelHasCollided()){
        uBall->changeState(U4DBallStateDecelerate::sharedInstance());
    }
     
}

void U4DBallStateDribbling::exit(U4DBall *uBall){
    
    
    
}

bool U4DBallStateDribbling::isSafeToChangeState(U4DBall *uBall){
    
    return true;
}

bool U4DBallStateDribbling::handleMessage(U4DBall *uBall, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
