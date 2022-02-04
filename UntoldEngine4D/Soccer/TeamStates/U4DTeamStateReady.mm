//
//  U4DTeamStateReady.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/3/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DTeamStateReady.h"
#include "CommonProtocols.h"
#include "U4DTeamStateDefending.h"
#include "U4DTeamStateAttacking.h"

namespace U4DEngine{

U4DTeamStateReady* U4DTeamStateReady::instance=0;

U4DTeamStateReady::U4DTeamStateReady(){
    name="Team Ready";
}

U4DTeamStateReady::~U4DTeamStateReady(){
    
}

U4DTeamStateReady* U4DTeamStateReady::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DTeamStateReady();
    }
    
    return instance;
    
}

void U4DTeamStateReady::enter(U4DTeam *uTeam){
    
    
    uTeam->formationManager.computeHomePosition();
    
}

void U4DTeamStateReady::execute(U4DTeam *uTeam, double dt){
    
    
    
}

void U4DTeamStateReady::exit(U4DTeam *uTeam){
    
    uTeam->formationTimer->setPause(false);
}

bool U4DTeamStateReady::isSafeToChangeState(U4DTeam *uTeam){
    
    return true;
}

bool U4DTeamStateReady::handleMessage(U4DTeam *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgTeamStart: 
        {
            if (uTeam->aiTeam==true) {
                uTeam->changeState(U4DTeamStateDefending::sharedInstance());
            }else{
                uTeam->changeState(U4DTeamStateAttacking::sharedInstance());
            }
        }
            break;
            
        default:
            break;
    }
    
    return false;
    
}

}
