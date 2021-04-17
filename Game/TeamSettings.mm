//
//  TeamSettings.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "TeamSettings.h"

TeamSettings* TeamSettings::instance=0;

TeamSettings::TeamSettings(){
    
}

TeamSettings::~TeamSettings(){
    
}

TeamSettings* TeamSettings::sharedInstance(){
    
    if (instance==0) {
        
        instance=new TeamSettings();
        
    }
    
    return instance;
}

void TeamSettings::setTeamAKit(std::vector<U4DEngine::U4DVector4n> &uKitContainer){
    
    teamAKitContainer=uKitContainer;
}

void TeamSettings::setTeamBKit(std::vector<U4DEngine::U4DVector4n> &uKitContainer){
    
    teamBKitContainer=uKitContainer;
}

std::vector<U4DEngine::U4DVector4n> &TeamSettings::getTeamAKit(){
    
    return teamAKitContainer;
}

std::vector<U4DEngine::U4DVector4n> &TeamSettings::getTeamBKit(){
    
    return teamBKitContainer;
}
