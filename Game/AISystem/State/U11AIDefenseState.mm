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
#include "U11AIRecoverState.h"
#include "U11Team.h"
#include "U11Player.h"
#include "U11PlayerDefendState.h"

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
    
    //set all players to defend
    for(auto n:uAISystem->getTeam()->getTeammates()){
        n->changeState(U11PlayerDefendState::sharedInstance());
        
    }
    
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

            uAISystem->changeState(U11AIRecoverState::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
    
    
}
