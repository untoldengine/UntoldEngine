//
//  FormationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "FormationManager.h"

FormationManager::FormationManager(){
    
    U4DEngine::U4DVector3n s0(2.0,0.0,-2.0);
    U4DEngine::U4DVector3n s1(-2.0,0.0,-2.0);
    U4DEngine::U4DVector3n s2(-4.0,0.0,2.0);
    U4DEngine::U4DVector3n s3(0.0,0.0,2.0);
    U4DEngine::U4DVector3n s4(4.0,0.0,2.0);
    
    spots.push_back(s0);
    spots.push_back(s1);
    spots.push_back(s2);
    spots.push_back(s3);
    spots.push_back(s4);
    
    computeHomePosition();
    
}

FormationManager::~FormationManager(){
    
}



void FormationManager::computeHomePosition(){
    
    U4DEngine::U4DVector3n groupPosition(0.0,0.0,0.0);
    
    for(const auto&n:spots){
        
        groupPosition+=n;
        
    }
        
    homePosition=groupPosition/spots.size();
    currentPosition=homePosition;
}

void FormationManager::computeFormationPosition(U4DEngine::U4DVector3n uOffsetPosition){
    
    formationPositions.clear();
    
    U4DEngine::U4DVector3n groupPosition(0.0,0.0,0.0);
    
    for(const auto&n:spots){
        
        formationPositions.push_back(n+uOffsetPosition-currentPosition);
        
    }
    
    currentPosition=uOffsetPosition;
    
}

U4DEngine::U4DVector3n FormationManager::getFormationPositionAtIndex(int uIndex){
    
    U4DEngine::U4DVector3n position;
    
    position=formationPositions.at(uIndex);
    
    return position;
    
}
