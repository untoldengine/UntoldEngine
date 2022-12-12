//
//  U4DPlayerStateRunning.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/11/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateRunning.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DPlayerStateMark.h"
#include "U4DPlayerStateGoHome.h"
#include "U4DPlayerStateFalling.h"

#include "U4DGameConfigs.h"

namespace U4DEngine {

U4DPlayerStateRunning* U4DPlayerStateRunning::instance=0;

U4DPlayerStateRunning::U4DPlayerStateRunning(){
    name="running";
}

U4DPlayerStateRunning::~U4DPlayerStateRunning(){
    
}

U4DPlayerStateRunning* U4DPlayerStateRunning::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateRunning();
    }
    
    return instance;
    
}

void U4DPlayerStateRunning::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    //U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    U4DAnimation *currentAnimation=uPlayer->getAnimationForState(name);
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    
}

void U4DPlayerStateRunning::execute(U4DPlayer *uPlayer, double dt){
    
//    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
//
//    U4DEngine::U4DVector3n finalVelocity=(uPlayer->dribblingDirection)*20.0;
    
//    if(uPlayer->kineticAction->getModelHasCollided()){
//
//        finalVelocity*=-10.0;
//        finalVelocity.y=0.0;
//        U4DVector3n zero(0.0,0.0,0.0);
//        uPlayer->kineticAction->setAngularVelocity(zero);
//
//    }
    
    
    
//    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
//        uPlayer->applyVelocity(finalVelocity, dt);
//        uPlayer->setViewDirection(finalVelocity);
//
//    }
}

void U4DPlayerStateRunning::exit(U4DPlayer *uPlayer){
    
    
}

bool U4DPlayerStateRunning::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateRunning::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
