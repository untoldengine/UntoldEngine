//
//  U11PlayerInterceptPassState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerInterceptPassState.h"
#include "U11PlayerTakeBallControlState.h"
#include "U11PlayerDefendState.h"
#include "U11Team.h"

U11PlayerInterceptPassState* U11PlayerInterceptPassState::instance=0;

U11PlayerInterceptPassState::U11PlayerInterceptPassState(){
    
}

U11PlayerInterceptPassState::~U11PlayerInterceptPassState(){
    
}

U11PlayerInterceptPassState* U11PlayerInterceptPassState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerInterceptPassState();
    }
    
    return instance;
    
}

void U11PlayerInterceptPassState::enter(U11Player *uPlayer){
    
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
    uPlayer->setEntityType(U4DEngine::MODEL);
    
    
}

void U11PlayerInterceptPassState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->interseptBall();
    
    //has the player reached the ball
    if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        uPlayer->removeKineticForces();
        
        //intercepted pass
        
        //we can set the player to take ball control. But for now, we are going to set it to its defaut defending state.
        uPlayer->changeState(U11PlayerDefendState::sharedInstance());
        
    }
}

void U11PlayerInterceptPassState::exit(U11Player *uPlayer){
    
    uPlayer->setEntityType(U4DEngine::MODELNOSHADOWS);
    
}

bool U11PlayerInterceptPassState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerInterceptPassState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
