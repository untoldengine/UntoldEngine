//
//  U4DPursuit.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DPursuit.h"
#include "U4DDynamicAction.h"
#include "U4DModel.h"

namespace U4DEngine {
    
    U4DPursuit::U4DPursuit(){
        
    }
    
    U4DPursuit::~U4DPursuit(){
        
    }
    
    U4DVector3n U4DPursuit::getSteering(U4DDynamicAction *uPursuer, U4DDynamicAction *uEvader){
        
        U4DVector3n toEvader=uEvader->model->getAbsolutePosition()-uPursuer->model->getAbsolutePosition();
        
        float speed=uEvader->getVelocity().magnitude();
        
        //set the time
        float lookAheadTime=toEvader.magnitude()/(5.0+speed);
        
        //compute the predicted target position
        U4DVector3n targetPosition=uEvader->model->getAbsolutePosition()+uEvader->getVelocity()*lookAheadTime;
        
        return U4DSeek::getSteering(uPursuer, targetPosition);
        
    }
    
}
