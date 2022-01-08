//
//  U4DPlayerStateHalt.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/16/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DPlayerStateHalt.h"
#include "U4DPlayerStateIdle.h"
#include "U4DPlayerStateJog.h"
#include "U4DGameConfigs.h"
#include "U4DBall.h"
#include "U4DFoot.h"
#include "U4DMessageDispatcher.h"
#include "U4DTeam.h"

namespace U4DEngine {

U4DPlayerStateHalt* U4DPlayerStateHalt::instance=0;

U4DPlayerStateHalt::U4DPlayerStateHalt(){
    name="halt";
}

U4DPlayerStateHalt::~U4DPlayerStateHalt(){
    
}

U4DPlayerStateHalt* U4DPlayerStateHalt::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DPlayerStateHalt();
    }
    
    return instance;
    
}

void U4DPlayerStateHalt::enter(U4DPlayer *uPlayer){
    
    //play the idle animation
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->haltAnimation;
    
    if (currentAnimation!=nullptr) {
        uPlayer->animationManager->setAnimationToPlay(currentAnimation);
    }
    
    uPlayer->foot->kineticAction->resumeCollisionBehavior();
    
    U4DTeam *team=uPlayer->getTeam();
    
    std::vector<U4DPlayer*> teammates=team->getTeammatesForPlayer(uPlayer);
    U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();
    
    for(auto n: teammates){
        messageDispatcher->sendMessage(0.0, uPlayer, n, msgIdle);
    }
}

void U4DPlayerStateHalt::execute(U4DPlayer *uPlayer, double dt){
    
    U4DEngine::U4DAnimation *currentAnimation=uPlayer->haltAnimation;
    
    uPlayer->updateFootSpaceWithAnimation(currentAnimation);
    
    uPlayer->haltBall=false;
    
    //check the distance between the player and the ball
    U4DBall *ball=U4DBall::sharedInstance();
    U4DEngine::U4DVector3n ballPosition=ball->getAbsolutePosition();
    ballPosition.y=uPlayer->getAbsolutePosition().y;
    
    float distanceToBall=(ballPosition-uPlayer->getAbsolutePosition()).magnitude();
    
    if(uPlayer->foot->kineticAction->getModelHasCollided()){
        
        uPlayer->foot->setKickBallParameters(0.0,uPlayer->dribblingDirection);
        uPlayer->applyForce(0.0, dt);
        uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        
    }else if (currentAnimation->getAnimationIsPlaying()==false) {
        
        U4DGameConfigs *gameConfigs=U4DGameConfigs::sharedInstance();
        
        if (distanceToBall>gameConfigs->getParameterForKey("haltRadius")) {
        
            uPlayer->setEnableHalt(true);

            uPlayer->changeState(U4DPlayerStateJog::sharedInstance());
            
        }else{
        
            uPlayer->changeState(U4DPlayerStateIdle::sharedInstance());
        }
        
    }
    
    
    
}

void U4DPlayerStateHalt::exit(U4DPlayer *uPlayer){
    
}

bool U4DPlayerStateHalt::isSafeToChangeState(U4DPlayer *uPlayer){
    
    return true;
}

bool U4DPlayerStateHalt::handleMessage(U4DPlayer *uPlayer, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}

}
