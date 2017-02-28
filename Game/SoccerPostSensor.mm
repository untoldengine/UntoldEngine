//
//  SoccerPostSensor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPostSensor.h"
#include "UserCommonProtocols.h"

void SoccerPostSensor::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        initAsPlatform(true);
        initMass(10000.0);
        initCoefficientOfRestitution(0.9);
        enableCollisionBehavior();
        //setNarrowPhaseBoundingVolumeVisibility(true);
        
        setCollisionFilterCategory(kSoccerPostSensor);
        setCollisionFilterMask(kSoccerBall);
        
        loadRenderingInformation();
    }
    
    
}

void SoccerPostSensor::update(double dt){
    
    if (getModelHasCollided()) {
        //soccerBallEntity->changeState(kBallHitPostSensor);
    }
    
}

void SoccerPostSensor::setBallEntity(SoccerBall *uSoccerBall){
    
    soccerBallEntity=uSoccerBall;
}
