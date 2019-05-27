//
//  U4DWander.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DWander.h"
#include "U4DDynamicModel.h"
#include "U4DNumerical.h"

namespace U4DEngine {
    
    U4DWander::U4DWander():wanderOffset(3.0),wanderRadius(2.0),wanderRate(0.5){
        
    }
    
    U4DWander::~U4DWander(){
        
    }
    
    U4DVector3n U4DWander::getSteering(U4DDynamicModel *uDynamicModel, U4DVector3n &uTargetPosition){
        
        U4DNumerical numerical;
        
        wanderOrientation=U4DEngine::U4DVector3n(numerical.getRandomNumberBetween(-1.0, 1.0)*wanderRate,0.0,numerical.getRandomNumberBetween(-1.0, 1.0)*wanderRate);
        
        float biasMotionAccumulator=0.98;

        wanderOrientationAccumulator=wanderOrientationAccumulator*biasMotionAccumulator+wanderOrientation*(1.0-biasMotionAccumulator);
        
        //calculate the combined target orientation
        U4DEngine::U4DVector3n viewDir=uDynamicModel->getViewInDirection();
        
        U4DEngine::U4DVector3n targetOrientation=viewDir+wanderOrientationAccumulator;
        
        //calculate the center of the wander circle
        U4DEngine::U4DVector3n targetPosition=uDynamicModel->getAbsolutePosition()+viewDir*wanderOffset;
        
        //calculate the target location
        targetPosition+=targetOrientation*wanderRadius;
        
        return U4DSeek::getSteering(uDynamicModel, targetPosition);
        
    }
    
    void U4DWander::setWanderOffset(float uWanderOffset){
        
        wanderOffset=uWanderOffset;
        
    }
    
    void U4DWander::setWanderRadius(float uWanderRadius){
        
        wanderRadius=uWanderRadius;
        
    }
    
    void U4DWander::setWanderRate(float uWanderRate){
        
        wanderRate=uWanderRate;
        
    }
    
}
