//
//  U4DPlayerStateFree.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/18/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateFree.h"
#include "U4DGameConfigs.h"
#include "U4DPlayerStateDribbling.h"
#include "U4DPlayerStateIntercept.h"
#include "U4DPlayerStateJog.h"
#include "U4DTeam.h"
#include "U4DBall.h"

namespace U4DEngine {

U4DPlayerStateFree* U4DPlayerStateFree::instance=0;

U4DPlayerStateFree::U4DPlayerStateFree(){
    name="free";
}

U4DPlayerStateFree::~U4DPlayerStateFree(){
    
}

U4DPlayerStateFree* U4DPlayerStateFree::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateFree();
    }
    
    return instance;
    
}

void U4DPlayerStateFree::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->runningAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    U4DTeam *team=uPlayer->getTeam();
    
    team->setControllingPlayer(uPlayer);
    
    //set speed
    uPlayer->arriveBehavior.setMaxSpeed(gameConfigs->getParameterForKey("freeMaxSpeed"));

    //set the distance to stop
    uPlayer->arriveBehavior.setTargetRadius(gameConfigs->getParameterForKey("freeStopRadius"));

    //set the distance to start slowing down
    uPlayer->arriveBehavior.setSlowRadius(gameConfigs->getParameterForKey("freeSlowRadius"));
    
}

void U4DPlayerStateFree::execute(U4DPlayer *uPlayer, double dt){
    
    U4DEngine::U4DGameConfigs *gameConfigs=U4DEngine::U4DGameConfigs::sharedInstance();
    
    uPlayer->updateFootSpaceWithAnimation(uPlayer->runningAnimation);
    
    U4DVector3n freeVelocity=uPlayer->dribblingDirection;
    
    U4DBall *ball=U4DBall::sharedInstance();
    
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    float distanceToBall=(ballPosition-uPlayer->getAbsolutePosition()).magnitude();
    
//    if (distanceToBall<gameConfigs->getParameterForKey("freeStopRadius")) {
//
//        uPlayer->changeState(U4DPlayerStateJog::sharedInstance());
//    }
    
    //compute the final velocity
    U4DEngine::U4DVector3n finalVelocity=uPlayer->arriveBehavior.getSteering(uPlayer->kineticAction, ballPosition);
    
    //finalVelocity=freeVelocity*gameConfigs->getParameterForKey("freeMaxSpeed")*0.2+finalVelocity*0.8;
    finalVelocity=freeVelocity*gameConfigs->getParameterForKey("freeMaxSpeed");
    
    //set the final y-component to zero
    finalVelocity.y=0.0;
    
    if(!(finalVelocity==U4DEngine::U4DVector3n(0.0,0.0,0.0))){
        
        uPlayer->applyVelocity(finalVelocity, dt);
        uPlayer->setViewDirection(finalVelocity);

    }
    
}

void U4DPlayerStateFree::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateFree::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateFree::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgChaseBall:
        {
            uPlayer->changeState(U4DPlayerStateDribbling::sharedInstance());
        }
            
        break;
        
        case msgInterceptBall:
        {
            uPlayer->changeState(U4DPlayerStateIntercept::sharedInstance());
        }
        break;
            
        default:
            break;
    }
    
    return false;
    
}

}
