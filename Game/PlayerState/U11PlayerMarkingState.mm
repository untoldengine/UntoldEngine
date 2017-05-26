//
//  U11PlayerMarkingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerMarkingState.h"
#include "U11PlayerDefendState.h"
#include "U11PlayerTapToStealState.h"
#include "U11Team.h"

U11PlayerMarkingState* U11PlayerMarkingState::instance=0;

U11PlayerMarkingState::U11PlayerMarkingState(){
    
}

U11PlayerMarkingState::~U11PlayerMarkingState(){
    
}

U11PlayerMarkingState* U11PlayerMarkingState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11PlayerMarkingState();
    }
    
    return instance;
    
}

void U11PlayerMarkingState::enter(U11Player *uPlayer){
    
    uPlayer->setNextAnimationToPlay(uPlayer->getMarkingAnimation());
    uPlayer->setPlayBlendedAnimation(true);
    
}

void U11PlayerMarkingState::execute(U11Player *uPlayer, double dt){
    
    uPlayer->seekBall();
    
    if (uPlayer->distanceToBall()>stealingDistanceToBall && uPlayer->distanceToBall()<markingDistanceToBall) {
        
        //make the player run
        uPlayer->applyForceToPlayer(markingSpeed, dt);
        
    }else{
        
        uPlayer->removeAllVelocities();
        uPlayer->removeKineticForces();
            
        uPlayer->changeState(U11PlayerTapToStealState::sharedInstance());
        
    }
    
}

void U11PlayerMarkingState::exit(U11Player *uPlayer){
    
}

bool U11PlayerMarkingState::isSafeToChangeState(U11Player *uPlayer){
    
    return true;
}

bool U11PlayerMarkingState::handleMessage(U11Player *uPlayer, Message &uMsg){
    
    
    return false;
    
}
