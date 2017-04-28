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
        
        setShader("nonVisibleShader");
        
        setEntityType(U4DEngine::MODELNOSHADOWS);
        
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

