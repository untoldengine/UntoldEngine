//
//  U11TeamDefendingState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11TeamDefendingState.h"
#include "U11Team.h"
#include "U11PlayerDefendState.h"


U11TeamDefendingState *U11TeamDefendingState::instance=0;

U11TeamDefendingState::U11TeamDefendingState(){
    
}

U11TeamDefendingState::~U11TeamDefendingState(){
    
}

U11TeamDefendingState *U11TeamDefendingState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11TeamDefendingState();
    }
    
    return instance;
    
}

void U11TeamDefendingState::enter(U11Team *uTeam){
    
    //initialize the timer to compute the best defending position
    uTeam->startComputeDefendingSpaceTimer();
    
}

void U11TeamDefendingState::execute(U11Team *uTeam, double dt){
    
    
}

void U11TeamDefendingState::exit(U11Team *uTeam){
    
    //remove the timer which computes the best defending position
    uTeam->removeComputeDefendingStateTimer();
}

bool U11TeamDefendingState::handleMessage(U11Team *uTeam, Message &uMsg){
    
}
