//
//  U11TeamIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/4/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11TeamIdleState.h"
#include "U11Team.h"

U11TeamIdleState *U11TeamIdleState::instance=0;

U11TeamIdleState::U11TeamIdleState(){
    
}

U11TeamIdleState::~U11TeamIdleState(){
    
}

U11TeamIdleState *U11TeamIdleState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11TeamIdleState();
    }
    
    return instance;
    
}

void U11TeamIdleState::enter(U11Team *uTeam){
    
}

void U11TeamIdleState::execute(U11Team *uTeam, double dt){
    
    
}

void U11TeamIdleState::exit(U11Team *uTeam){
    
    
}

bool U11TeamIdleState::handleMessage(U11Team *uTeam, Message &uMsg){
    
}
