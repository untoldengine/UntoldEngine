//
//  TeamStateGoingHome.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "TeamStateGoingHome.h"
#include "MessageDispatcher.h"
#include "PlayerStateIdle.h"
#include "TeamStateReady.h"

TeamStateGoingHome* TeamStateGoingHome::instance=0;

TeamStateGoingHome::TeamStateGoingHome(){
    name="Team Going Home";
}

TeamStateGoingHome::~TeamStateGoingHome(){
    
}

TeamStateGoingHome* TeamStateGoingHome::sharedInstance(){
    
    if (instance==0) {
        instance=new TeamStateGoingHome();
    }
    
    return instance;
    
}

void TeamStateGoingHome::enter(Team *uTeam){
    
    //send formation to home
    U4DEngine::U4DVector3n homePosition(0.0,0.0,2.0);
    
    uTeam->formationManager.computeFormationPosition(homePosition);
    
    for(auto &n:uTeam->getPlayers()){
    
        //reset all flags
        n->resetAllFlags();
        
        //send message to player
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

        messageDispatcher->sendMessage(0.0, uTeam, n, msgGoHome);
        

    }
    
}

void TeamStateGoingHome::execute(Team *uTeam, double dt){
    
    bool playersAtHome=true;
    
    //test if all players are ready in idle mode
    for(auto &n:uTeam->getPlayers()){
    
        if (n->atHome==false) {
            playersAtHome=false;
            break;
        }
        
    }
    
    if (playersAtHome==true) {
        uTeam->changeState(TeamStateReady::sharedInstance());
    }
    
}

void TeamStateGoingHome::exit(Team *uTeam){
    
}

bool TeamStateGoingHome::isSafeToChangeState(Team *uTeam){
    
    return true;
}

bool TeamStateGoingHome::handleMessage(Team *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
        
            
        default:
            break;
    }
    
    return false;
    
}
