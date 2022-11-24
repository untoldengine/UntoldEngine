//
//  U4DFormationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DFormationManager.h"
#include "U4DVector2n.h"

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


    void U4DFormationManager::divideFieldIntoZones(float uHalfWidth, float uHalfHeight){
        
        U4DVector2n f0(0.0,0.0);
        U4DVector2n f1(uHalfWidth/6.0, 3.0*uHalfHeight/4.0);
        U4DVector2n f2(2.0*uHalfWidth/6.0, 1.5*uHalfHeight/4.0);
        U4DVector2n f3(3.0*uHalfWidth/6.0, 3.0*uHalfHeight/4.0);
        U4DVector2n f4(5.0*uHalfWidth/6.0, 3.0*uHalfHeight/4.0);
        
        //reflect about y-axis
        U4DVector2n f5(-f1.x,f1.y);
        U4DVector2n f6(-f2.x,f2.y);
        U4DVector2n f7(-f3.x,f3.y);
        U4DVector2n f8(-f4.x,f4.y);
        
        //reflect about x-axis
        U4DVector2n f9(f1.x,-f1.y);
        U4DVector2n f10(f2.x,-f2.y);
        U4DVector2n f11(f3.x,-f3.y);
        U4DVector2n f12(f4.x,-f4.y);
        
        //reflect about origin
        U4DVector2n f13=f1*-1.0;
        U4DVector2n f14=f2*-1.0;
        U4DVector2n f15=f3*-1.0;
        U4DVector2n f16=f4*-1.0;
        
    }

}
