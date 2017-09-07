//
//  U11FormationEntity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11FormationEntity.h"

U11FormationEntity::U11FormationEntity():assigned(false){
    
}

U11FormationEntity::~U11FormationEntity(){
    
}

void U11FormationEntity::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName,uBlenderFile)) {
        
        originPosition=getAbsolutePosition();
        
        setShader("vertexNonVisibleShader","fragmentNonVisibleShader");
        
        setEntityType(U4DEngine::MODELNOSHADOWS);
        
        //Get body dimensions
        float xDimension=bodyCoordinates.getModelDimension().x;
        float yDimension=bodyCoordinates.getModelDimension().y;
        float zDimension=bodyCoordinates.getModelDimension().z;
        
        //get min and max points to create the AABB
        U4DEngine::U4DPoint3n minPoints(-xDimension/2.0,-yDimension/2.0,-zDimension/2.0);
        U4DEngine::U4DPoint3n maxPoints(xDimension/2.0,yDimension/2.0,zDimension/2.0);
        
        aabbBox.setMinPoint(minPoints);
        aabbBox.setMaxPoint(maxPoints);
        
        loadRenderingInformation();
    }
}

void U11FormationEntity::update(double dt){
    
    
}

void U11FormationEntity::translateToOriginPosition(){
    
    translateTo(originPosition);
    
}

bool U11FormationEntity::isAssigned(){
    
    return assigned;
}

void U11FormationEntity::setAssigned(bool uValue){
    
    assigned=uValue;
}

U4DEngine::U4DAABB &U11FormationEntity::getAABBBox(){

    return aabbBox;
}

