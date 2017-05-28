//
//  U11AIRecoverState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AIRecoverState.h"
#include "U11AISystem.h"
#include "U11SpaceAnalyzer.h"
#include "U11MessageDispatcher.h"
#include "UserCommonProtocols.h"
#include "U11Team.h"
#include "U11Player.h"
#include "U11PlayerIdleState.h"

U11AIRecoverState* U11AIRecoverState::instance=0;

U11AIRecoverState::U11AIRecoverState(){
    
}

U11AIRecoverState::~U11AIRecoverState(){
    
}

U11AIRecoverState* U11AIRecoverState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11AIRecoverState();
    }
    
    return instance;
    
}

void U11AIRecoverState::enter(U11AISystem *uAISystem){
    
    //set all players to idle
    for(auto n:uAISystem->getTeam()->getTeammates()){
        n->changeState(U11PlayerIdleState::sharedInstance());

    }
    
    //initialize the timer to compute the closest player
    
    uAISystem->getRecoverAISystem().startComputeClosestPlayerTimer();
    
}

void U11AIRecoverState::execute(U11AISystem *uAISystem, double dt){
    

    
}

void U11AIRecoverState::exit(U11AISystem *uAISystem){

    //end timer
    uAISystem->getRecoverAISystem().removeComputeClosestPlayerTimer();
}

bool U11AIRecoverState::handleMessage(U11AISystem *uAISystem, Message &uMsg){
    
    return false;
    
}
