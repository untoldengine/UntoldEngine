//
//  U4DTeamStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DTeamStateIdle.h"

namespace U4DEngine{

U4DTeamStateIdle* U4DTeamStateIdle::instance=0;

U4DTeamStateIdle::U4DTeamStateIdle(){
    name="Team Idle";
}

U4DTeamStateIdle::~U4DTeamStateIdle(){
    
}

U4DTeamStateIdle* U4DTeamStateIdle::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DTeamStateIdle();
    }
    
    return instance;
    
}

void U4DTeamStateIdle::enter(U4DTeam *uTeam){
    
   
    
}

void U4DTeamStateIdle::execute(U4DTeam *uTeam, double dt){
    
    
    
}

void U4DTeamStateIdle::exit(U4DTeam *uTeam){
    
}

bool U4DTeamStateIdle::isSafeToChangeState(U4DTeam *uTeam){
    
    return true;
}

bool U4DTeamStateIdle::handleMessage(U4DTeam *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
//        case msgTeamVictory:
//
//            //uTeam->changeState(TeamStateVictory::sharedInstance());
//
//            break;
            
        default:
            break;
    }
    
    return false;
    
}

}

