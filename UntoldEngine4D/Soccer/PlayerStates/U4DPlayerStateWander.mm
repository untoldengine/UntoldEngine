//
//  U4DPlayerStateWander.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateWander.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DBall.h"

namespace U4DEngine {

U4DPlayerStateWander* U4DPlayerStateWander::instance=0;

U4DPlayerStateWander::U4DPlayerStateWander(){
    name="wander";
}

U4DPlayerStateWander::~U4DPlayerStateWander(){
    
}

U4DPlayerStateWander* U4DPlayerStateWander::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateWander();
    }
    
    return instance;
    
}

void U4DPlayerStateWander::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->wanderBehavior.setWanderOffset(1.0);
    
    uPlayer->wanderBehavior.setWanderRadius(1.0);
    
    uPlayer->wanderBehavior.setWanderRate(1.0);
}

void U4DPlayerStateWander::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
    
    
    U4DEngine::U4DVector3n pos=uPlayer->getAbsolutePosition();
    
    U4DEngine::U4DVector3n finalVelocity=uPlayer->wanderBehavior.getSteering(uPlayer->kineticAction, pos);
    
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);

    }
}

void U4DPlayerStateWander::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateWander::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateWander::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgInterceptBall:
        {
            uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());
        }
        break;
            
        case msgSupport:
        {
            uPlayer->changeState(U4DPlayerStateFlock::sharedInstance());
            
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

}
