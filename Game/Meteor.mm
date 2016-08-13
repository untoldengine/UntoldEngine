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
//        translateTo(0.0,5.0,0.0);
        enableCollision();
  //      applyPhysics(true);
    //    setCoefficientOfRestitution(0.6);
    }
}

void Meteor::update(double dt){
    
    rotateBy(0.0,1.0,0.0);
    
}