//
//  Rock.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Rock.h"
#include "U4DDigitalAssetLoader.h"

Rock::Rock(){
    
}

Rock::~Rock(){
    
}

void Rock::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //initialize everything else here
        enableCollisionBehavior();
        initCoefficientOfRestitution(0.0);
        
        loadRenderingInformation();
    }
    
    
}

void Rock::update(double dt){
    
}
