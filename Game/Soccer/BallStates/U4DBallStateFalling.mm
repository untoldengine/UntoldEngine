//
//  U4DBallStateFalling.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/4/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DBallStateFalling.h"
#include "U4DBallStateIdle.h"

namespace U4DEngine {

U4DBallStateFalling* U4DBallStateFalling::instance=0;

U4DBallStateFalling::U4DBallStateFalling(){
    name="falling";
}

U4DBallStateFalling::~U4DBallStateFalling(){
    
}

U4DBallStateFalling* U4DBallStateFalling::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DBallStateFalling();
    }
    
    return instance;
    
}

void U4DBallStateFalling::enter(U4DBall *uBall){
    
    uBall->kineticAction->resetGravity();
    uBall->kineticAction->resumeCollisionBehavior();

}

void U4DBallStateFalling::execute(U4DBall *uBall, double dt){
    
    if(uBall->kineticAction->getModelHasCollided()){
        
        std::vector<U4DStaticAction*> n=uBall->kineticAction->getCollisionList();
        
        if(n.size()>0){
            
            U4DModel *model=n.at(0)->model;
            
            uBall->setIntersectingObstacle(model);
            
            if (uBall->testObstacleIntersection()) {
                
                U4DVector3n zero(0.0,0.0,0.0);
                uBall->kineticAction->setGravity(zero);
                uBall->kineticAction->setVelocity(zero);
                uBall->kineticAction->setAngularVelocity(zero);

                uBall->changeState(U4DBallStateIdle::sharedInstance());
        
            }
            
        }
        
    }
}

void U4DBallStateFalling::exit(U4DBall *uBall){
    
    uBall->kineticAction->pauseCollisionBehavior();
    
}

bool U4DBallStateFalling::isSafeToChangeState(U4DBall *uBall){
    
    return true;
}

bool U4DBallStateFalling::handleMessage(U4DBall *uBall, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
