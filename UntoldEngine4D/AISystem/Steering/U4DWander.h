//
//  U4DWander.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DWander_hpp
#define U4DWander_hpp

#include <stdio.h>
#include "U4DSeek.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    class U4DDynamicAction;
}

namespace U4DEngine{
    
    /**
     @ingroup artificialintelligence
     @brief The U4DWander class implements AI steering Wander behavior
     */
    class U4DWander:public U4DSeek {
        
    private:
        
        U4DVector3n wanderOrientation;
        
        U4DVector3n wanderOrientationAccumulator;
        
        //wander circle offset
        float wanderOffset;
        
        //wander radius circle
        float wanderRadius;
        
        //random number for wonder target position
        float wanderRate;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DWander();
        
        /**
         @brief class destructor
         */
        ~U4DWander();
        
        /**
         @brief Computes the velocity for steering
         
         @param uAction Dynamic action represented as the pursuer
         @param uTargetPosition target position in vector format
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition);
        
        /**
         @brief sets the wander offset used for the Wander steering behavior. This represents the distance offset between the pursuer and the wander target
         
         @param uWanderOffset distance offset
         */
        void setWanderOffset(float uWanderOffset);
        
        /**
         @brief sets the wander circle radius for the Wander steering behavior
         
         @param uWanderRadius radius of wander circle
         */
        void setWanderRadius(float uWanderRadius);
        
        /**
         @brief sets the rate for the random number for wander target position
         
         @param uWanderRate wander rate
         */
        void setWanderRate(float uWanderRate);
        
    };
    
}
#endif /* U4DWander_hpp */
