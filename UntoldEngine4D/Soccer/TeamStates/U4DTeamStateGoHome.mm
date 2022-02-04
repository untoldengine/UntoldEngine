//
//  U4DTeamStateGoHome.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/3/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DTeamStateGoHome.h"
#include "U4DTeamStateReady.h"
#include "U4DMessageDispatcher.h"

namespace U4DEngine{

U4DTeamStateGoHome* U4DTeamStateGoHome::instance=0;

U4DTeamStateGoHome::U4DTeamStateGoHome(){
    name="Team Going Home";
}

U4DTeamStateGoHome::~U4DTeamStateGoHome(){
    
}

U4DTeamStateGoHome* U4DTeamStateGoHome::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DTeamStateGoHome();
    }
    
    return instance;
    
}

void U4DTeamStateGoHome::enter(U4DTeam *uTeam){
    
    uTeam->formationTimer->setPause(true);
    
    for(auto &n:uTeam->getPlayers()){
    
        //reset all flags
        n->resetAllFlags();
        
        //send message to player 
        U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();

        messageDispatcher->sendMessage(0.0, uTeam, n, msgGoHome);
        
        

    }
    
}

void U4DTeamStateGoHome::execute(U4DTeam *uTeam, double dt){
    
    bool playersAtHome=true;
    
    //test if all players are ready in idle mode
    for(auto &n:uTeam->getPlayers()){
    
        if (n->atHome==false) {
            playersAtHome=false;
            break;
        }
        
    }
    
    if (playersAtHome==true) {
        uTeam->changeState(U4DTeamStateReady::sharedInstance());
    }
    
}

void U4DTeamStateGoHome::exit(U4DTeam *uTeam){
    
}

bool U4DTeamStateGoHome::isSafeToChangeState(U4DTeam *uTeam){
    
    return true;
}

bool U4DTeamStateGoHome::handleMessage(U4DTeam *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        

        default:
            break;
    }
    
    return false;
    
}

}
