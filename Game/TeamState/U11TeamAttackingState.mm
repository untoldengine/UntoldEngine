//
//  U11TeamAttackingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11TeamAttackingState.h"
#include "U11Team.h"

U11TeamAttackingState *U11TeamAttackingState::instance=0;

U11TeamAttackingState::U11TeamAttackingState(){
    
}

U11TeamAttackingState::~U11TeamAttackingState(){
    
}

U11TeamAttackingState *U11TeamAttackingState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11TeamAttackingState();
    }
    
    return instance;
    
}

void U11TeamAttackingState::enter(U11Team *uTeam){
    
    //initialize the timer to compute the best supporting position
    uTeam->startComputeSupportSpaceTimer();

}

void U11TeamAttackingState::execute(U11Team *uTeam, double dt){
    
    //check if timer is up and compute best supporting position
    
}

void U11TeamAttackingState::exit(U11Team *uTeam){
    
    //remove the timer which computes the best supporting position
    uTeam->removeComputeSupportStateTimer();
}

bool U11TeamAttackingState::handleMessage(U11Team *uTeam, Message &uMsg){
    
}
