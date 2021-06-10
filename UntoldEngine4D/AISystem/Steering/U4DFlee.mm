//
//  U4DFlee.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DFlee.h"
#include "U4DDynamicAction.h"
#include "U4DModel.h"

namespace U4DEngine {
    
    U4DFlee::U4DFlee(){
        
    }
    
    U4DFlee::~U4DFlee(){
        
    }
    
    U4DVector3n U4DFlee::getSteering(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition){
        
        //get the desired velocity vector by subracting the current position of the character and of the target
        U4DEngine::U4DVector3n desiredVelocity=uAction->model->getAbsolutePosition()-uTargetPosition;
        
        //normalize the velocity. we just want the direction
        desiredVelocity.normalize();
        
        //set the speed
        desiredVelocity*=maxSpeed;
        
        U4DEngine::U4DVector3n finalVelocity=desiredVelocity-uAction->getVelocity();
        
        return finalVelocity;
        
    }
    
}
