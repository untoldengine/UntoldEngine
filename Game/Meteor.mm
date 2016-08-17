//
//  Meteor.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Meteor.h"

Meteor::Meteor(){
    
}

Meteor::~Meteor(){
    
}

void Meteor::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        translateTo(0.0,5.0,0.0);
        rotateTo(0.0,0.0,20.0);
    
        //initMass(5.0);
        U4DEngine::U4DVector3n gravity(0.0,-5.0,0.0);
        setGravity(gravity);
        
        initCoefficientOfRestitution(0.9);
        enableCollisionBehavior();
        enableKineticsBehavior();
        
        setShader("gouraudShader");
        
    }
}

void Meteor::update(double dt){
    
    //rotateBy(0.0,1.0,0.0);
    
}