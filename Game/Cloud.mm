//
//  Cloud.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/21/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "Cloud.h"

Cloud::Cloud(){
    
}

Cloud::~Cloud(){
    
}

void Cloud::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        setShader("gouraudShader");
        
    }
}

void Cloud::update(double dt){
    
}