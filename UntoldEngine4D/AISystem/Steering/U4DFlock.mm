//
//  U4DFlock.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "U4DFlock.h"
#include "U4DDynamicAction.h"
#include "U4DSeparation.h"
#include "U4DAlign.h"
#include "U4DCohesion.h"
#include "Constants.h"

namespace U4DEngine {

U4DFlock::U4DFlock():maxSpeed(25.0),desiredSeparation(5.0),neighborDistanceAlignment(20.0),neighborDistanceCohesion(20.0){
            
        }

    U4DFlock::~U4DFlock(){
        
    }


    U4DVector3n U4DFlock::getSteering(U4DDynamicAction *uPursuer, std::vector<U4DDynamicAction*> uNeighborsContainer){
        
        U4DSeparation separationBehavior;
        U4DAlign alignBehavior;
        U4DCohesion cohesionBehavior;
        
        //set max speed
        separationBehavior.setMaxSpeed(maxSpeed);
        alignBehavior.setMaxSpeed(maxSpeed);
        cohesionBehavior.setMaxSpeed(maxSpeed);
        
        //set neighbor distance
        separationBehavior.setDesiredSeparation(desiredSeparation);
        alignBehavior.setNeighborDistance(neighborDistanceAlignment);
        cohesionBehavior.setNeighborDistance(neighborDistanceCohesion);
        
        U4DVector3n separationDesiredVelocity=separationBehavior.getSteering(uPursuer,uNeighborsContainer);
        U4DVector3n cohesionDesiredVelocity=cohesionBehavior.getSteering(uPursuer,uNeighborsContainer);
        U4DVector3n alignDesiredVelocity=alignBehavior.getSteering(uPursuer,uNeighborsContainer);
        
        U4DVector3n finalDesiredVelocity;
        
//        //Priorities: 1. Separation. 2. Alignment. 3. Cohesion
//        if(separationDesiredVelocity.magnitudeSquare()>U4DEngine::zeroEpsilon) {
//
//            finalDesiredVelocity=separationDesiredVelocity;
//
//        }else if(alignDesiredVelocity.magnitudeSquare()>U4DEngine::zeroEpsilon) {
//
//            finalDesiredVelocity=alignDesiredVelocity;
//
//        }else{
//
//            finalDesiredVelocity=cohesionDesiredVelocity;
//        }
        
        //Using blending for the final flocking velocity
        finalDesiredVelocity=(separationDesiredVelocity+alignDesiredVelocity+cohesionDesiredVelocity)*0.33;
        
        return finalDesiredVelocity;
        
    }

    void U4DFlock::setMaxSpeed(float uMaxSpeed){
        
        maxSpeed=uMaxSpeed;
        
    }

    void U4DFlock::setNeighborsDistance(float uNeighborSeparationDistance, float uNeighborAlignDistance, float uNeighborCohesionDistance){
        
        desiredSeparation=uNeighborSeparationDistance;
        neighborDistanceAlignment=uNeighborAlignDistance;
        neighborDistanceCohesion=uNeighborCohesionDistance;
        
    }

}
