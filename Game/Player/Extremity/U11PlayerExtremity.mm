//
//  U11PlayerExtremity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11PlayerExtremity.h"
#include "UserCommonProtocols.h"
#include "U11Ball.h"

U11PlayerExtremity::U11PlayerExtremity(){
    
}

U11PlayerExtremity::~U11PlayerExtremity(){
    
}

void U11PlayerExtremity::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        setShader("nonVisibleShader");
        initMass(0.0);
        initAsPlatform(true);
        initCoefficientOfRestitution(0.0);
        enableCollisionBehavior();
        
        setCollisionFilterCategory(kU11PlayerExtremity);
        setCollisionFilterMask(kU11Ball);
        
        //set player collision with ball filter to occur
        setCollisionFilterGroupIndex(kPlayerExtremitiesGroupIndex);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        loadRenderingInformation();
        
    }
    
}

void U11PlayerExtremity::update(double dt){
    
    if (getModelHasCollided()) {
        
    }
    
}

void U11PlayerExtremity::setBoneToFollow(std::string uBoneName){
    
    boneToFollow=uBoneName;
    
}

std::string U11PlayerExtremity::getBoneToFollow(){
 
    return boneToFollow;
}

float U11PlayerExtremity::distanceToBall(U11Ball *uU11Ball){
    
    U4DEngine::U4DVector3n ballPosition=uU11Ball->getAbsolutePosition();
    
    U4DEngine::U4DVector3n extremityPosition=getAbsolutePosition();
    
    float ballRadius=uU11Ball->getBallRadius();
    
    float distance=(ballPosition-extremityPosition).magnitude()-ballRadius;
    
    return distance;
    
}
