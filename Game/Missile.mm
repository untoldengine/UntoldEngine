//
//  Missile.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "Missile.h"
#include "U4DDigitalAssetLoader.h"

Missile::Missile(){
    
}

Missile::~Missile(){
    
}

void Missile::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableCollisionBehavior();
        initCoefficientOfRestitution(0.0);
        
        loadRenderingInformation();
    }
    
    
}

void Missile::update(double dt){
    
}
