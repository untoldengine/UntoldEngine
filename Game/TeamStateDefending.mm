//
//  TeamStateDefending.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "TeamStateDefending.h"
#include "MessageDispatcher.h"
#include "PlayAnalyzer.h"
#include "TeamStateGoingHome.h"

TeamStateDefending* TeamStateDefending::instance=0;

TeamStateDefending::TeamStateDefending(){
    
    name="Team Defending";

}

TeamStateDefending::~TeamStateDefending(){
    
}

TeamStateDefending* TeamStateDefending::sharedInstance(){
    
    if (instance==0) {
        instance=new TeamStateDefending();
    }
    
    return instance;
    
}

void TeamStateDefending::enter(Team *uTeam){
    
    uTeam->defenseTimer->setPause(false);
    uTeam->formationTimer->setPause(false);
}

void TeamStateDefending::execute(Team *uTeam, double dt){
    
    if(uTeam->enableDefenseAnalyzer==true){
        
        //get closest player to intersect the ball
        PlayAnalyzer *playAnalyzer=PlayAnalyzer::sharedInstance(); 

        Player *teammate=playAnalyzer->closestTeammateToIntersectBall(uTeam);

        //send message to player
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

        messageDispatcher->sendMessage(0.0, uTeam, teammate, msgMark);
        
        uTeam->enableDefenseAnalyzer=false;
        
    }
    
}

void TeamStateDefending::exit(Team *uTeam){
    
    uTeam->defenseTimer->setPause(true);
    uTeam->formationTimer->setPause(true);
}

bool TeamStateDefending::isSafeToChangeState(Team *uTeam){
    
    return true;
}

bool TeamStateDefending::handleMessage(Team *uTeam, Message &uMsg){
    
    switch (uMsg.msg) {
        
        case msgGoHome:
            
            uTeam->changeState(TeamStateGoingHome::sharedInstance());
            
            break;
            
        default:
            break;
    }
    
    return false;
    
}
