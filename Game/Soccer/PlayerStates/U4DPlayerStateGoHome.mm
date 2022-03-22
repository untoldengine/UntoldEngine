//
//  U4DPlayerStateGoHome.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/3/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateGoHome.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateIdle.h"

namespace U4DEngine {

U4DPlayerStateGoHome* U4DPlayerStateGoHome::instance=0;

U4DPlayerStateGoHome::U4DPlayerStateGoHome(){
    name="going home";
}

U4DPlayerStateGoHome::~U4DPlayerStateGoHome(){
    
}

U4DPlayerStateGoHome* U4DPlayerStateGoHome::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateGoHome();
    }
    
    return instance;
    
}

void U4DPlayerStateGoHome::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("goingHomeVelocity"));
    
    //remove all flags
    uPlayer->resetAllFlags();
    
}

void U4DPlayerStateGoHome::execute(U4DPlayer *uPlayer, double dt){
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
    
    U4DVector3n homePosition=uPlayer->homePosition;
    
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, homePosition);
    
    //U4DEngine::U4DVector3n avoidanceBehavior=uPlayer->avoidanceBehavior.getSteering(uPlayer->kineticAction);

//    if (uPlayer->kineticAction->getModelHasCollidedBroadPhase()) {
//        finalVelocity=finalVelocity*0.8+avoidanceBehavior*0.2;
//    }
    
    //set the final y-component to zero
    finalVelocity.y=0.0;

    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setMoveDirection(finalVelocity);
        
    }else{
        
        U4DEngine::U4DVector3n playerHomeDirection(0.0,uPlayer->getAbsolutePosition().y,0.0);
        
        uPlayer->viewInDirection(playerHomeDirection);
        
        uPlayer->atHome=true;
        uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        
    }
    
}

void U4DPlayerStateGoHome::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateGoHome::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateGoHome::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
