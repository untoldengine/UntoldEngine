//
//  GameAsset.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "GameAsset.h"
#include "UserCommonProtocols.h"
GameAsset::GameAsset(){
    
}

GameAsset::~GameAsset(){
    
}

bool GameAsset::init(const char* uModelName, const char* uBlenderFile){
    
    if (loadModel(uModelName, uBlenderFile)) {
    
        setEnableShadow(true);
        
        setCollidingTag("floor");
        
        initAsPlatform(true);
        
        enableCollisionBehavior();
        
        initCoefficientOfRestitution(0.7);
        
        U4DEngine::U4DVector3n grav(0.0,0.0,0.0);
        
        setGravity(grav);
        
        initMass(1000.0);
        
        pauseKineticsBehavior();
        
        setCollisionFilterCategory(kField);
        setCollisionFilterMask(kCube);
        
        loadRenderingInformation();
        
        //setBroadPhaseBoundingVolumeVisibility(true);
        
        return true;
    }
    
    return false;
}

void GameAsset::update(double dt){
    
}
