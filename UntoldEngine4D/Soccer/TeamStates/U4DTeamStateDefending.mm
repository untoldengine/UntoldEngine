//
//  U4DTeamStateDefending.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/8/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DTeamStateDefending.h"
#include "U4DMessageDispatcher.h"
#include "U4DPlayAnalyzer.h"
#include "U4DTeamStateAttacking.h"
#include "U4DPlayerStateFree.h"
#include "U4DPlayerStateIdle.h"

namespace U4DEngine{

U4DTeamStateDefending* U4DTeamStateDefending::instance=0;

U4DTeamStateDefending::U4DTeamStateDefending(){
    
    name="Team Defending";

}

U4DTeamStateDefending::~U4DTeamStateDefending(){
    
}

U4DTeamStateDefending* U4DTeamStateDefending::sharedInstance(){
    
    if (instance==0) {
        instance=new U4DTeamStateDefending();
    }
    
    return instance;
    
}

void U4DTeamStateDefending::enter(U4DTeam *uTeam){
    
    if(uTeam->aiTeam){
        uTeam->defenseTimer->setPause(false);
        //uTeam->formationTimer->setPause(false);
        
        for(auto &n:uTeam->getPlayers()){
            //uTeam->formationTimer->setPause(false);
            n->setEnableDribbling(false);
            n->setEnableFreeToRun(false);
            n->setEnableHalt(false);
            
        }
        
    }else{
        //for now, let's just set the player's state as free
        
        for(auto &n:uTeam->getPlayers()){
            n->resetAllFlags();
            n->changeState(U4DPlayerStateIdle::sharedInstance());
        }
        
        uTeam->getActivePlayer()->setEnableFreeToRun(true);
        
    }
    
}

void U4DTeamStateDefending::execute(U4DTeam *uTeam, double dt){
    
    if(uTeam->enableDefenseAnalyzer==true && uTeam->aiTeam){
        
        //get closest player to intersect the ball
        U4DPlayAnalyzer *playAnalyzer=U4DPlayAnalyzer::sharedInstance();

        U4DPlayer *teammate=playAnalyzer->closestTeammateToIntersectBall(uTeam);

        //send message to player
        U4DMessageDispatcher *messageDispatcher=U4DMessageDispatcher::sharedInstance();

        messageDispatcher->sendMessage(0.0, uTeam, teammate, msgMark);
        
        uTeam->enableDefenseAnalyzer=false;
        
    }
    
}

void U4DTeamStateDefending::exit(U4DTeam *uTeam){
    
    if(uTeam->aiTeam){
        uTeam->defenseTimer->setPause(true);
        uTeam->formationTimer->setPause(true);
    }
    
}

bool U4DTeamStateDefending::isSafeToChangeState(U4DTeam *uTeam){
    
    return true;
}

bool U4DTeamStateDefending::handleMessage(U4DTeam *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
//        case msgGoHome:
//
//            uTeam->changeState(TeamStateGoingHome::sharedInstance());
//
//            break;
//
//        case msgTeamAttack:
//
//            uTeam->changeState(TeamStateAttacking::sharedInstance());
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
