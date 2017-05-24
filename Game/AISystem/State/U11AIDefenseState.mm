//
//  U11AIDefenseState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AIDefenseState.h"
#include "U11AISystem.h"
#include "U11DefenseAISystem.h"
#include "UserCommonProtocols.h"

U11AIDefenseState* U11AIDefenseState::instance=0;

U11AIDefenseState::U11AIDefenseState(){
    
}

U11AIDefenseState::~U11AIDefenseState(){
    
}

U11AIDefenseState* U11AIDefenseState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11AIDefenseState();
    }
    
    return instance;
    
}

void U11AIDefenseState::enter(U11AISystem *uAISystem){
    
    //initialize the timer to compute the best defending position
    uAISystem->getDefenseAISystem().startComputeDefendingSpaceTimer();
    
}

void U11AIDefenseState::execute(U11AISystem *uAISystem, double dt){
    
   
}

void U11AIDefenseState::exit(U11AISystem *uAISystem){
    
    //remove the timer which computes the best defending position
    uAISystem->getDefenseAISystem().removeComputeDefendingSpaceTimer();
    
}

bool U11AIDefenseState::handleMessage(U11AISystem *uAISystem, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgBallPassed:
            
            //get message that the ball was passed
            uAISystem->getDefenseAISystem().interceptPass();
            
            break;
            
        case msgBallRelinquished:
            
            break;
            
        default:
            break;
    }
    
    return false;
    
    
}
