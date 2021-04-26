//
//  TeamStateAttacking.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "TeamStateAttacking.h"
#include "MessageDispatcher.h"
#include "UserCommonProtocols.h"
#include "TeamStateGoingHome.h"

TeamStateAttacking* TeamStateAttacking::instance=0;

TeamStateAttacking::TeamStateAttacking(){
    
    name="Team Attacking";

}

TeamStateAttacking::~TeamStateAttacking(){
    
}

TeamStateAttacking* TeamStateAttacking::sharedInstance(){
    
    if (instance==0) {
        instance=new TeamStateAttacking();
    }
    
    return instance;
    
}

void TeamStateAttacking::enter(Team *uTeam){
    
    for(auto &n:uTeam->getPlayers()){
        
        //send message to player
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

        messageDispatcher->sendMessage(0.0, uTeam, n, msgChaseBall);
        
    }
    
}

void TeamStateAttacking::execute(Team *uTeam, double dt){
    
    
    
}

void TeamStateAttacking::exit(Team *uTeam){
    
}

bool TeamStateAttacking::isSafeToChangeState(Team *uTeam){
    
    return true;
}

bool TeamStateAttacking::handleMessage(Team *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgGoHome:
            
            uTeam->changeState(TeamStateGoingHome::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
