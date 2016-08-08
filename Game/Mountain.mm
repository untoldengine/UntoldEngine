//
//  Mountain.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/4/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Mountain.h"


Mountain::Mountain(){
    
}

Mountain::~Mountain(){
    
}

void Mountain::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        //do your magic here

    }
}

void Mountain::update(double dt){
    
}

