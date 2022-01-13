//
//  U4DTeamStateAttacking.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DTeamStateAttacking.h"
#include "U4DMessageDispatcher.h"
#include "CommonProtocols.h"
#include "U4DTeamStateDefending.h"
#include "U4DPlayerStateIdle.h"

namespace U4DEngine{

U4DTeamStateAttacking* U4DTeamStateAttacking::instance=0;

U4DTeamStateAttacking::U4DTeamStateAttacking(){
    
    name="Team Attacking";

}

U4DTeamStateAttacking::~U4DTeamStateAttacking(){
    
}

U4DTeamStateAttacking* U4DTeamStateAttacking::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DTeamStateAttacking();
    }
    
    return instance;
    
}

void U4DTeamStateAttacking::enter(U4DTeam *uTeam){
    
    if(uTeam->aiTeam==true){
        
        //start the field timer analyzer
        //uTeam->analyzerFieldTimer->setPause(false);
        //uTeam->formationTimer->setPause(false);
        uTeam->defenseTimer->setPause(true);
        
        for(auto &n:uTeam->getPlayers()){
            n->resetAllFlags();
        }
        
    }else{
        //for now, let's just set the player's state as free
        
        for(auto &n:uTeam->getPlayers()){
            //uTeam->formationTimer->setPause(false);
            n->setEnableDribbling(false);
            n->setEnableFreeToRun(false);
            n->setEnableHalt(false);
            
        }
        
    }
    
}

void U4DTeamStateAttacking::execute(U4DTeam *uTeam, double dt){
    
    
    
}

void U4DTeamStateAttacking::exit(U4DTeam *uTeam){
    
    if(uTeam->aiTeam==true){
        //wont' be calling the path analyzer for now.
        //uTeam->analyzerFieldTimer->setPause(true);
        uTeam->formationTimer->setPause(true);
    }
    
}

bool U4DTeamStateAttacking::isSafeToChangeState(U4DTeam *uTeam){
    
    return true;
}

bool U4DTeamStateAttacking::handleMessage(U4DTeam *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
//        case msgGoHome:
//
//            uTeam->changeState(TeamStateGoingHome::sharedInstance());
//
//            break;
//
//        case msgTeamDefend:
//
//            uTeam->changeState(TeamStateDefending::sharedInstance());
//
//            break;
//
//        case msgTeamVictory:
//
//            uTeam->changeState(TeamStateVictory::sharedInstance());
//
//            break;
            
        default:
            break;
    }
    
    return false;
    
}

}

