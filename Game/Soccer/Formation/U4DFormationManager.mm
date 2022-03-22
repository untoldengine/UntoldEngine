//
//  U4DFormationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DFormationManager.h"


namespace U4DEngine {

    U4DFormationManager::U4DFormationManager(){
            
    }

    U4DFormationManager::~U4DFormationManager(){
            
    }

    void U4DFormationManager::computeHomePosition(){
        
        U4DVector3n groupPosition(0.0,0.0,0.0);
        
        for(const auto&n:spots){
            
            groupPosition+=n;
            
        }
            
        homePosition=groupPosition/spots.size();
        currentPosition=homePosition;
    }

    void U4DFormationManager::computeFormationPosition(U4DVector3n uOffsetPosition){
        
        formationPositions.clear();
        
        for(auto &n:spots){
            
            U4DVector3n pos=(uOffsetPosition-currentPosition)+n;
            
            formationPositions.push_back(pos);
            
            n=pos;
            
        }
        
        currentPosition=uOffsetPosition;
        
    }

    U4DVector3n U4DFormationManager::getFormationPositionAtIndex(int uIndex){
        
        U4DVector3n position;
        if (formationPositions.size()>0) {
            position=formationPositions.at(uIndex);
        }
        
        return position;
        
    }

}
