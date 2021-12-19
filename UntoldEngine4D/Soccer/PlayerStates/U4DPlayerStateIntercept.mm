//
//  U4DPlayerStateIntercept.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateIntercept.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DBall.h"
#include "U4DFoot.h"
#include "U4DTeam.h"

namespace U4DEngine {

U4DPlayerStateIntercept* U4DPlayerStateIntercept::instance=0;

U4DPlayerStateIntercept::U4DPlayerStateIntercept(){
    name="intercept";
}

U4DPlayerStateIntercept::~U4DPlayerStateIntercept(){
    
}

U4DPlayerStateIntercept* U4DPlayerStateIntercept::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateIntercept();
    }
    
    return instance;
    
}

void U4DPlayerStateIntercept::enter(U4DPlayer *uPlayer){
    
    U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    //play the idle animation
    U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    //set max speed for pursuit
    uPlayer->pursuitBehavior.setMaxSpeed(gameConfigs->getParameterForKey("pursuitMaxSpeed"));
    
}

void U4DPlayerStateIntercept::execute(U4DPlayer *uPlayer, double dt){
    
    U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
    
    U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    U4DVector3n finalVelocity=uPlayer->pursuitBehavior.getSteering(uPlayer->kineticAction, ball->kineticAction);
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){

        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setViewDirection(finalVelocity);

    }else{
        
       //check the distance between the player and the ball
      
    }
    
    float distanceToBall=(ballPosition-uPlayer->getAbsolutePosition()).magnitude();

    if (distanceToBall<gameConfigs->getParameterForKey("interceptMinRadius")) {

        uPlayer->changeState(U4DPlayerStateDribbling::sharedInstance());

    }
}

void U4DPlayerStateIntercept::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateIntercept::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateIntercept::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgChaseBall:
        {
            uPlayer->changeState(U4DPlayerStateDribbling::sharedInstance());
        }
            
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}

}
