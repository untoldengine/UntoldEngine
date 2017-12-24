//
//  ModelAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/23/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "ModelAsset.h"

ModelAsset::ModelAsset(){
    
    
}

ModelAsset::~ModelAsset(){
    
    U4DEngine::U4DEntity *parent=getParent();
    
    parent->removeChild(this);
    
}

bool ModelAsset::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
        
        setEnableShadow(true);
        
        initMass(5.0);

        initCoefficientOfRestitution(0.7);
        
        enableCollisionBehavior();
        
        loadRenderingInformation();
        
        //setBroadPhaseBoundingVolumeVisibility(true);
        
        return true;
        
    }
    
    return false;
}

void ModelAsset::update(double dt){
    
    if (getModelHasCollided()) {
        
    }
    
}
