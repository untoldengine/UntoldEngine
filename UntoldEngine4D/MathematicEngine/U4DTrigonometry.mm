//
//  U4DTrigonometry.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/14/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DTrigonometry.h"
#include <cmath>

namespace U4DEngine {
    
    U4DTrigonometry::U4DTrigonometry(){
        
    }
    
    U4DTrigonometry::~U4DTrigonometry(){
        
    }
    
    float U4DTrigonometry::degreesToRad(float uAngle){
        return (uAngle*M_PI/180.0);
    }
    
    
    float U4DTrigonometry::radToDegrees(float uAngle){
        return (uAngle*180.0/M_PI);
    }
}