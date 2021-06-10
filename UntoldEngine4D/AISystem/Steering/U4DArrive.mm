//
//  U4DArrive.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DArrive.h"
#include "U4DModel.h"
#include "U4DDynamicAction.h"

namespace U4DEngine {
    
    U4DArrive::U4DArrive():targetRadius(0.5),slowRadius(3.0){
        
    }
    
    U4DArrive::~U4DArrive(){
        
    }
    
    U4DVector3n U4DArrive::getSteering(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition){
        
        //Get the direction to the target
        U4DVector3n desiredVelocity=uTargetPosition-uAction->model->getAbsolutePosition();
        
        float distance=desiredVelocity.magnitude();
        
        float targetSpeed=0.0;
        
        //check if we are within the target radius. If so, return a velocity of zero
        if (distance<targetRadius) {
            return U4DVector3n(0.0,0.0,0.0);
        }
        
        //if we are outside the slowradius, then go max speed
        if (distance>slowRadius) {
            
            targetSpeed=maxSpeed;
            
        }else{
            //otherwise calculate a scaled speed
            targetSpeed=maxSpeed*distance/slowRadius;
        }
        
        //normalize the velocity. we just want the direction
        desiredVelocity.normalize();
        
        //set the speed
        desiredVelocity*=targetSpeed;
        
        //Compute the final velocity by subtracting the desired velocity minus the current velocity of the character
        U4DEngine::U4DVector3n finalVelocity=desiredVelocity-uAction->getVelocity();
        
        return finalVelocity;
        
    }
    
    void U4DArrive::setTargetRadius(float uTargetRadius){
        
        targetRadius=uTargetRadius;
        
    }
    
    void U4DArrive::setSlowRadius(float uSlowRadius){
        
        slowRadius=uSlowRadius;
        
    }
    
}
