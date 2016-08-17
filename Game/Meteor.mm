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
        translateTo(3.0,5.0,0.0);
        rotateTo(90.0,0.0,0.0);
    
        //initMass(5.0);
        initCoefficientOfRestitution(0.9);
        enableCollisionBehavior();
        enableKineticsBehavior();
        
        setShader("gouraudShader");
        
    }
}

void Meteor::update(double dt){
    
    //rotateBy(0.0,1.0,0.0);
    
}