//
//  U4DSteering.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSteering_hpp
#define U4DSteering_hpp

#include <stdio.h>
#include "U4DVector3n.h"
#include "U4DSegment.h"

namespace U4DEngine {
    class U4DDynamicAction;
}

namespace U4DEngine {
    
    /**
     @ingroup artificialintelligence
     @brief The U4DSteering class implements AI steering behaviors
     */
    class U4DSteering {
        
    private:
        
    protected:
        
        /**
         @brief maximum speed for steering
         */
        float maxSpeed;
        
    public:
        
        /**
         @brief class constructor for steering behavior
         */
        U4DSteering();
        
        /**
         @brief class destructor for steering behavior
         */
        ~U4DSteering();
        
        /**
         @brief Computes the velocity for steering

         @param uAction Dynamic action represented as the pursuer
         @param uTargetPosition target position in vector format
         @return velocity vector to apply to 3D model
         */
        virtual U4DVector3n getSteering(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition){};
        
        
        /**
         @brief Computes the velocity for steering

         @param uPursuer 3D model represented as the pursuer
         @param uEvader 3D model represented as the evader. Also known as the target
         @return velocity vector to apply to 3D model
         */
        virtual U4DVector3n getSteering(U4DDynamicAction *uPursuer, U4DDynamicAction *uEvader){};
        
        
        /**
         @brief Computes the velociry for steering along the provided path

         @param uAction Dynamic action represented as the pursuer
         @param uPathContainer segment vector representing the path the pursuer must follow
         @return velocity vector to apply to 3D model
         */
        virtual U4DVector3n getSteering(U4DDynamicAction *uAction, std::vector<U4DSegment> &uPathContainer){};
        
        /**
         @brief Computes the velocity for steering

         @param uAction Dynamic action represented as the pursuer
         @return velocity vector to apply to 3D model
         */
        virtual U4DVector3n getSteering(U4DDynamicAction *uAction){};
        
        
        /**
         @brief sets the maximum speed for steering

         @param uMaxSpeed maximum steering speed
         */
        void setMaxSpeed(float uMaxSpeed);
        
        
        /**
         @brief sets the wander offset used for the Wander steering behavior. This represents the distance offset between the pursuer and the wander target

         @param uWanderOffset distance offset
         */
        virtual void setWanderOffset(float uWanderOffset){};
        
        
        /**
         @brief sets the wander circle radius for the Wander steering behavior

         @param uWanderRadius radius of wander circle
         */
        virtual void setWanderRadius(float uWanderRadius){};
        
        
        /**
         @brief sets the rate for the random number for wander target position

         @param uWanderRate wander rate
         */
        virtual void setWanderRate(float uWanderRate){};
        
        
        /**
         @brief sets the time in the future to predict the position

         @param uPredictTime time value
         */
        virtual void setPredictTime(float uPredictTime){};
        
        
        /**
         @brief set the distance along the path to generate the target position

         @param uPathOffset path offset
         */
        virtual void setPathOffset(float uPathOffset){};
        
        
        /**
         @brief set the path radius

         @param uPathRadius radius of path
         */
        virtual void setPathRadius(float uPathRadius){};
        
        
        /**
         @brief gets the current path the pursuer is following

         @return index in the path(segment) vector
         */
        virtual int getCurrentPathIndex(){};
        
    };
    
}

#endif /* U4DSteering_hpp */
