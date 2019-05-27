//
//  U4DSteering.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DSteering.h"

namespace U4DEngine {
    
    U4DSteering::U4DSteering():maxSpeed(3.0){
        
    }
    
    U4DSteering::~U4DSteering(){
        
    }
    
    void U4DSteering::setMaxSpeed(float uMaxSpeed){
        
        maxSpeed=uMaxSpeed;
        
    }
    
}
