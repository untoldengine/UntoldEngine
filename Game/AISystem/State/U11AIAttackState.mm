//
//  U11AIAttackState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11AIAttackState.h"
#include "U11AISystem.h"
#include "U11AttackAISystem.h"
#include "U11AIRecoverState.h"
#include "U11Team.h"
#include "U11Player.h"
#include "U11PlayerAttackState.h"

U11AIAttackState* U11AIAttackState::instance=0;

U11AIAttackState::U11AIAttackState(){
    
}

U11AIAttackState::~U11AIAttackState(){
    
}

U11AIAttackState* U11AIAttackState::sharedInstance(){
    
    if (instance==0) {
        instance=new U11AIAttackState();
    }
    
    return instance;
    
}

void U11AIAttackState::enter(U11AISystem *uAISystem){
    
    //set all players to idle
    for(auto n:uAISystem->getTeam()->getTeammates()){
        n->changeState(U11PlayerAttackState::sharedInstance());
        
    }
    
    //assign support player
    uAISystem->getAttackAISystem().assignSupportPlayer();
    
    //initialize the timer to compute the best supporting position
    uAISystem->getAttackAISystem().startComputeSupportSpaceTimer();
    
}

void U11AIAttackState::execute(U11AISystem *uAISystem, double dt){
    
    
}

void U11AIAttackState::exit(U11AISystem *uAISystem){
    
    //remove the timer which computes the best supporting position
    uAISystem->getAttackAISystem().removeComputeSupportSpaceTimer();
    
}

bool U11AIAttackState::handleMessage(U11AISystem *uAISystem, Message &uMsg){
    
    switch (uMsg.msg) {
            
        case msgBallRelinquished:
            
            uAISystem->changeState(U11AIRecoverState::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
