//
//  Rocket.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Rocket.h"
#include "U4DDigitalAssetLoader.h"

Rocket::Rocket(){
    
}

Rocket::~Rocket(){
    
}

void Rocket::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
    }
    
    
}

void Rocket::update(double dt){
    
    U4DEngine::U4DVector3n vec(0.0,0.0,1.0);
    U4DEngine::U4DQuaternion q(1.0,vec);
    
    rotateBy(q);
}