//
//  U4DPlayerStateJump.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/1/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateJump.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateFlock.h"
#include "U4DPlayerStateMark.h"
#include "U4DPlayerStateGoHome.h"
#include "U4DPlayerStateFalling.h"

namespace U4DEngine {

U4DPlayerStateJump* U4DPlayerStateJump::instance=0;

U4DPlayerStateJump::U4DPlayerStateJump(){
    name="jumping";
}

U4DPlayerStateJump::~U4DPlayerStateJump(){
    
}

U4DPlayerStateJump* U4DPlayerStateJump::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateJump();
    }
    
    return instance;
    
}

void U4DPlayerStateJump::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->idleAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
  
    maxHeight=uPlayer->getAbsolutePosition().y;
}

void U4DPlayerStateJump::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->idleAnimation);
    
    U4DEngine::U4DVector3n finalVelocity=(uPlayer->dribblingDirection)*15.0;
    

    finalVelocity.y=5.0;
    
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setViewDirection(finalVelocity);

    }
    
    if((uPlayer->getAbsolutePosition().y-maxHeight)>2.0){
        uPlayer->changeState(U4DPlayerStateFalling::sharedInstance());
    }
}

void U4DPlayerStateJump::exit(U4DPlayer *uPlayer){
    
    
}

bool U4DPlayerStateJump::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateJump::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
