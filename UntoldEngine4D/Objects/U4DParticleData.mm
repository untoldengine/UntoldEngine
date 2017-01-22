//
//  U4DParticleData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/17/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DParticleData.h"


namespace U4DEngine {
    
    U4DParticleData::U4DParticleData(){
        
    }
    
    U4DParticleData::~U4DParticleData(){
        
    }

    void U4DParticleData::addVerticesDataToContainer(U4DVector3n& uData){
        
        verticesContainer.push_back(uData);
    }
    
    std::vector<U4DVector3n> U4DParticleData::getVerticesDataFromContainer(){
        
        return verticesContainer;
        
    }
    
    void U4DParticleData::addIndexDataToContainer(U4DIndex& uData){
        
        indexContainer.push_back(uData);
    }
    
    void U4DParticleData::addVelocityDataToContainer(U4DVector3n& uData){
        
        velocityContainer.push_back(uData);
    }
    
    std::vector<U4DVector3n> U4DParticleData::getVelocityDataFromContainer(){
        
        return velocityContainer;
    }
    
    void U4DParticleData::addStartTimeDataToContainer(float &uData){
        
        startTimeContainer.push_back(uData);
    }
    
    std::vector<float> U4DParticleData::getStartTimeDataFromContainer(){
        
        return startTimeContainer;
        
    }
    
}
