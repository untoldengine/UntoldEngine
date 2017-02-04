//
//  SoccerPost.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/2/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#include "SoccerPost.h"
#include "UserCommonProtocols.h"

void SoccerPost::init(const char* uName, const char* uBlenderFile){
    
    if (loadModel(uName, uBlenderFile)) {
        
        loadRenderingInformation();
    }
    
    
}

void SoccerPost::update(double dt){
    
    
    
}
