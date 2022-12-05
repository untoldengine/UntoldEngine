//
//  U4DFormationManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DFormationManager.h"
#include "U4DLogger.h"

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


std::vector<U4DVector4n> U4DFormationManager::divideFieldIntoZones(float uHalfWidth, float uHalfHeight){
        
    std::vector<U4DVector4n> zoneContainer;

    float halfWidthStep=uHalfWidth/6.0;
    float halfHeightStep=uHalfHeight/4.0;

    U4DVector4n f0(0.0,0.0,4.0*halfWidthStep,2.0*halfHeightStep);
    U4DVector4n f1(uHalfWidth/6.0, 3.0*uHalfHeight/4.0,1.0*halfWidthStep,1.0*halfHeightStep);
    U4DVector4n f2(2.0*uHalfWidth/6.0, 1.5*uHalfHeight/4.0,2.0*halfWidthStep,0.5*halfHeightStep);
    U4DVector4n f3(3.0*uHalfWidth/6.0, 3.0*uHalfHeight/4.0, halfWidthStep, halfHeightStep);
    U4DVector4n f4(5.0*uHalfWidth/6.0, 3.0*uHalfHeight/4.0,halfWidthStep,halfHeightStep);


    //reflect about y-axis
    U4DVector4n f5(-f1.x,f1.y,1.0*halfWidthStep,1.0*halfHeightStep);
    U4DVector4n f6(-f2.x,f2.y,2.0*halfWidthStep,0.5*halfHeightStep);
    U4DVector4n f7(-f3.x,f3.y,halfWidthStep, halfHeightStep);
    U4DVector4n f8(-f4.x,f4.y,halfWidthStep,halfHeightStep);

    //reflect about x-axis
    U4DVector4n f9(f1.x,-f1.y,1.0*halfWidthStep,1.0*halfHeightStep);
    U4DVector4n f10(f2.x,-f2.y,2.0*halfWidthStep,0.5*halfHeightStep);
    U4DVector4n f11(f3.x,-f3.y,halfWidthStep, halfHeightStep);
    U4DVector4n f12(f4.x,-f4.y,halfWidthStep, halfHeightStep);

    //reflect about origin
    U4DVector4n f13(-1.0*f1.x,-1.0*f1.y,1.0*halfWidthStep,1.0*halfHeightStep);
    U4DVector4n f14(-1.0*f2.x,-1.0*f2.y,2.0*halfWidthStep,0.5*halfHeightStep);
    U4DVector4n f15(-1.0*f3.x,-1.0*f3.y,halfWidthStep, halfHeightStep);
    U4DVector4n f16(-1.0*f4.x,-1.0*f4.y,halfWidthStep, halfHeightStep);

    zoneContainer.push_back(f0);
    zoneContainer.push_back(f1);
    zoneContainer.push_back(f2);
    zoneContainer.push_back(f3);
    zoneContainer.push_back(f4);

    zoneContainer.push_back(f5);
    zoneContainer.push_back(f6);
    zoneContainer.push_back(f7);
    zoneContainer.push_back(f8);

    zoneContainer.push_back(f9);
    zoneContainer.push_back(f10);
    zoneContainer.push_back(f11);
    zoneContainer.push_back(f12);

    zoneContainer.push_back(f13);
    zoneContainer.push_back(f14);
    zoneContainer.push_back(f15);
    zoneContainer.push_back(f16);

    U4DLogger *logger=U4DLogger::sharedInstance();
    logger->log("field had been divided into zones");
        
    return zoneContainer;
    
    }

}
