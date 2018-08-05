//
//  U4DPadAxis.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DPadAxis.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DPadAxis::U4DPadAxis(float uXAxis,float uYAxis):xAxis(uXAxis),yAxis(uYAxis){}
    
    U4DPadAxis::~U4DPadAxis(){}
    
    void U4DPadAxis::setPoint(float uXAxis,float uYAxis){
        xAxis=uXAxis;
        yAxis=uYAxis;
    }
    
    U4DVector2n U4DPadAxis::getPoint(){
        U4DVector2n padAxis;
        
        padAxis.x=this->xAxis;
        padAxis.y=this->yAxis;
        
        return padAxis;
    }
    
}
