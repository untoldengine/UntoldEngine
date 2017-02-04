//
//  SoccerGoalSensor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerGoalSensor.h"
#include "UserCommonProtocols.h"

void SoccerGoalSensor::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        initAsPlatform(true);
        initMass(0.0);
        initCoefficientOfRestitution(0.0);
        enableCollisionBehavior();
        //setNarrowPhaseBoundingVolumeVisibility(true);
        
        setCollisionFilterCategory(kSoccerGoalSensor);
        setCollisionFilterMask(kSoccerBall);
        
        loadRenderingInformation();
    }
    
    
}

void SoccerGoalSensor::update(double dt){
    
    if (getModelHasCollided()) {
        //soccerBallEntity->changeState(kGoal);
    }
    
}

void SoccerGoalSensor::setBallEntity(SoccerBall *uSoccerBall){
    
    soccerBallEntity=uSoccerBall;
}
