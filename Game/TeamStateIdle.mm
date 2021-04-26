//
//  TeamStateIdle.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "TeamStateIdle.h"
TeamStateIdle* TeamStateIdle::instance=0;

TeamStateIdle::TeamStateIdle(){
    name="Team Idle";
}

TeamStateIdle::~TeamStateIdle(){
    
}

TeamStateIdle* TeamStateIdle::sharedInstance(){
    
    if (instance==0) {
        instance=new TeamStateIdle();
    }
    
    return instance;
    
}

void TeamStateIdle::enter(Team *uTeam){
    
   
    
}

void TeamStateIdle::execute(Team *uTeam, double dt){
    
    
    
}

void TeamStateIdle::exit(Team *uTeam){
    
}

bool TeamStateIdle::isSafeToChangeState(Team *uTeam){
    
    return true;
}

bool TeamStateIdle::handleMessage(Team *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}
