//
//  U11Field.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "U11Field.h"
#include "UserCommonProtocols.h"
#include "U11BallBounceState.h"

U11Field::U11Field(){
    
}

U11Field::~U11Field(){
    
}

void U11Field::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        
        initAsPlatform(true);
        initMass(1000.0);
        initCoefficientOfRestitution(0.0);
        enableCollisionBehavior();
        
        setCollisionFilterCategory(kU11Field);
        setCollisionFilterMask(kU11Ball);
        setCollisionFilterGroupIndex(kNegativeGroupIndex);
        
        setEnableShadow(true);
        
        loadRenderingInformation();
        
    }
}

void U11Field::update(double dt){
    
    if (getModelHasCollided()) {
        soccerBall->changeState(U11BallBounceState::sharedInstance());
    }
}

void U11Field::setSoccerBall(U11Ball *uSoccerBall){
    
    soccerBall=uSoccerBall;
}

