//
//  ModelAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "ModelAsset.h"
#include "GameAsset.h"
#include "GuardianModel.h"
#include "UserCommonProtocols.h"

ModelAsset::ModelAsset(){
    
    
}

ModelAsset::~ModelAsset(){
    
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->removeChild(this);
    
}

bool ModelAsset::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(true);
        
        setCollidingTag("blocks");
        
        initMass(5.0);

        initCoefficientOfRestitution(0.7);
        
        enableCollisionBehavior();
        
        loadRenderingInformation();
        
        setCollisionFilterCategory(kCube);
        
        setCollisionFilterMask(kPlayer|kField);
        
        //setBroadPhaseBoundingVolumeVisibility(true);
        
        return true;
        
    }
    
    return false;
}

void ModelAsset::update(double dt){
    
    if (getModelHasCollided()) {
       
    }
    
}
