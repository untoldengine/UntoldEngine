//
//  Planet.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Planet.h"


Planet::Planet(){
    
}

Planet::~Planet(){
    
}

void Planet::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
    }
}

void Planet::update(double dt){
    
    rotateBy(0.0,1.0,0.0);
    
    
}