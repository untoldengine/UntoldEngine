//
//  U4DArrive.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DArrive_hpp
#define U4DArrive_hpp

#include <stdio.h>
#include "U4DSteering.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    class U4DDynamicModel;
}

namespace U4DEngine{
    
    /**
     @ingroup artificialintelligence
     @brief The U4DArrive class implements AI steering Arrive behavior
     */
    class U4DArrive:public U4DSteering {
        
    private:
        
        /**
         @brief holds the radius for arriving target
         */
        float targetRadius;
        
        /**
         @brief Holds the radius for beginning to slow down
         */
        float slowRadius;
        
    public:
        
        /**
         @brief class constructor
         */
        U4DArrive();
        
        /**
         @brief class destructor
         */
        ~U4DArrive();
        
        /**
         @brief Computes the velocity for steering
         
         @param uDynamicModel 3D model represented as the pursuer
         @param uTargetPosition target position in vector format
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicModel *uDynamicModel, U4DVector3n &uTargetPosition);
        
        
        /**
         @brief sets the radius distance to the target where the velocity of the pursuer should come to a stop

         @param uTargetRadius radius of circle to stop
         */
        void setTargetRadius(float uTargetRadius);
        
        
        /**
         @brief sets the radius distance to the target where the pursuer should slow down

         @param uSlowRadius radius of circle to slow down
         */
        void setSlowRadius(float uSlowRadius);
        
    };
    
}
#endif /* U4DArrive_hpp */
