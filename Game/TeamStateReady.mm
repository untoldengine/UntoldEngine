//
//  TeamStateReady.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "TeamStateReady.h"
#include "TeamStateDefending.h"
#include "TeamStateAttacking.h"
#include "UserCommonProtocols.h"

TeamStateReady* TeamStateReady::instance=0;

TeamStateReady::TeamStateReady(){
    name="Team Ready";
}

TeamStateReady::~TeamStateReady(){
    
}

TeamStateReady* TeamStateReady::sharedInstance(){
    
    if (instance==0) {
        instance=new TeamStateReady();
    }
    
    return instance;
    
}

void TeamStateReady::enter(Team *uTeam){
    
   
    
}

void TeamStateReady::execute(Team *uTeam, double dt){
    
    
    
}

void TeamStateReady::exit(Team *uTeam){
    
}

bool TeamStateReady::isSafeToChangeState(Team *uTeam){
    
    return true;
}

bool TeamStateReady::handleMessage(Team *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgTeamStart:
        {
            if (uTeam->aiTeam==true) {
                uTeam->changeState(TeamStateDefending::sharedInstance());
            }else{
                uTeam->changeState(TeamStateAttacking::sharedInstance());
            }
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}
