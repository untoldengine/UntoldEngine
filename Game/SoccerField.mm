//
//  SoccerField.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerField.h"

SoccerField::SoccerField(){
    
}

SoccerField::~SoccerField(){
    
}

void SoccerField::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
        initAsPlatform(true);
        //setBroadPhaseBoundingVolumeVisibility(true);
        //setNarrowPhaseBoundingVolumeVisibility(true);
        initMass(1.0);
        initCoefficientOfRestitution(0.5);
        enableCollisionBehavior();
        
        loadRenderingInformation();
        
    }
}

void SoccerField::update(double dt){
    
}
