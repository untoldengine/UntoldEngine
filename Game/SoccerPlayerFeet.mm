//
//  SoccerPlayerFeet.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerFeet.h"
#include "UserCommonProtocols.h"

SoccerPlayerFeet::SoccerPlayerFeet(){
    
}

SoccerPlayerFeet::~SoccerPlayerFeet(){
    
}

void SoccerPlayerFeet::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        //setShader("nonVisibleShader");
        initMass(0.0);
        initCoefficientOfRestitution(0.0);
        enableCollisionBehavior();
        
        setCollisionFilterCategory(kSoccerPlayer);
        setCollisionFilterMask(kSoccerBall);
        
        //set player collision with ball filter to occur
        setCollisionFilterGroupIndex(kZeroGroupIndex);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        loadRenderingInformation();
        
    }
    
}

void SoccerPlayerFeet::update(double dt){
    
    if (getModelHasCollided()) {
        
    }
    
}
