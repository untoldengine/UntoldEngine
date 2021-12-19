//
//  U4DTeam.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DTeam.h"

namespace U4DEngine{

U4DTeam::U4DTeam():controllingPlayer(nullptr){
    
}

U4DTeam::~U4DTeam(){
    
}

void U4DTeam::addPlayer(U4DPlayer *uPlayer){
    
    uPlayer->addToTeam(this);
    players.push_back(uPlayer);
    
}

std::vector<U4DPlayer *> U4DTeam::getPlayers(){
    
    return players;
    
}

std::vector<U4DPlayer *> U4DTeam::getTeammatesForPlayer(U4DPlayer *uPlayer){
    
    std::vector<U4DPlayer*> teammates;
    
    for(const auto &n:getPlayers()){ 
        
        if (n!=uPlayer) {
            teammates.push_back(n);
        }
        
    }
    
    return teammates;
    
}

void U4DTeam::setControllingPlayer(U4DPlayer *uPlayer){
    
    controllingPlayer=uPlayer;
    
}

U4DPlayer *U4DTeam::getControllingPlayer(){
    return controllingPlayer;
}


}
