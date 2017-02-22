//
//  SoccerPlayerExtremity.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/20/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPlayerExtremity.h"
#include "UserCommonProtocols.h"

SoccerPlayerExtremity::SoccerPlayerExtremity(){
    
}

SoccerPlayerExtremity::~SoccerPlayerExtremity(){
    
}

void SoccerPlayerExtremity::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        setShader("nonVisibleShader");
        initMass(0.0);
        initAsPlatform(true);
        initCoefficientOfRestitution(0.0);
        enableCollisionBehavior();
        
        setCollisionFilterCategory(kSoccerPlayer);
        setCollisionFilterMask(kSoccerBall);
        
        //set player collision with ball filter to occur
        setCollisionFilterGroupIndex(kPlayerExtremitiesGroupIndex);
        
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        
        setEntityForwardVector(viewDirectionVector);
        
        loadRenderingInformation();
        
    }
    
}

void SoccerPlayerExtremity::update(double dt){
    
    if (getModelHasCollided()) {
        
    }
    
}

void SoccerPlayerExtremity::setBoneToFollow(std::string uBoneName){
    
    boneToFollow=uBoneName;
    
}

std::string SoccerPlayerExtremity::getBoneToFollow(){
 
    return boneToFollow;
}
