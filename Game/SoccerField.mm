//
//  SoccerField.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerField.h"
#include "UserCommonProtocols.h"

SoccerField::SoccerField(){
    
}

SoccerField::~SoccerField(){
    
}

void SoccerField::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
        initAsPlatform(true);
        initMass(1000.0);
        initCoefficientOfRestitution(0.2);
        enableCollisionBehavior();
        
        setCollisionFilterCategory(kSoccerField);
        setCollisionFilterMask(kSoccerBall);
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        loadRenderingInformation();
        
    }
}

void SoccerField::update(double dt){
    
}
