//
//  U4DSeek.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DSeek.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
 
    U4DSeek::U4DSeek(){
        
    }
    
    U4DSeek::~U4DSeek(){
        
    }
    
    U4DVector3n U4DSeek::getSteering(U4DDynamicModel *uDynamicModel, U4DVector3n &uTargetPosition){
        
        //get the desired velocity vector by subracting the current position of the target and of the pursuer
        U4DEngine::U4DVector3n desiredVelocity=uTargetPosition-uDynamicModel->getAbsolutePosition();
        
        //normalize the velocity. we just want the direction
        desiredVelocity.normalize();
        
        //set the speed
        desiredVelocity*=maxSpeed;
        
        //Compute the final velocity by subtracting the desired velocity minus the current velocity of the character
        U4DEngine::U4DVector3n finalVelocity=desiredVelocity-uDynamicModel->getVelocity();
        
        return finalVelocity;
        
    }
    
}
