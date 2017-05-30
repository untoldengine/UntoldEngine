//
//  U11PlayerInterceptState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/10/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerInterceptState.h"
#include "U11PlayerRecoverState.h"
#include "U11Team.h"
#include "U11AIStateManager.h"
#include "U11AISystem.h"
#include "U11AIDefenseState.h"
#include "U11AIAttackState.h"
#include "U11AIRecoverState.h"


U11PlayerInterceptState* U11PlayerInterceptState::instance=0;

U11PlayerInterceptState::U11PlayerInterceptState(){
    
}

U11PlayerInterceptState::~U11PlayerInterceptState(){
    
}

U11PlayerInterceptState* U11PlayerInterceptState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerInterceptState();
    }
    
    return instance;
    
}

void U11PlayerInterceptState::enter(U11Player *uPlayer){
    
    //set run animation
    uPlayer->setNextAnimationToPlay(uPlayer->getRunningAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    uPlayer->setPlayNextAnimationContinuously(true);
    
    U11Team *team=uPlayer->getTeam();
    
    team->setControllingPlayer(uPlayer);
        
    
}

void U11PlayerInterceptState::execute(U11Player *uPlayer, double dt){
    
    //track the ball
    uPlayer->interseptBall();
    
    //has the player reached the ball 
    if (!uPlayer->hasReachedTheBall()) {
        
        //chase the ball
        uPlayer->applyForceToPlayer(chasingSpeed, dt);
        
    }else{
        
        //intercepted pass
        uPlayer->removeKineticForces();
        
        U11Ball *ball=uPlayer->getSoccerBall();
        
        ball->removeKineticForces();
        
        ball->removeAllVelocities();
        
        uPlayer->changeState(U11PlayerRecoverState::sharedInstance());
        
    }
}

void U11PlayerInterceptState::exit(U11Player *uPlayer){
    
    
}

bool U11PlayerInterceptState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerInterceptState::handleMessage(U11Player *uPlayer, Message &uMsg){
    return false;
}
