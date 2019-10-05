//
//  U4DAvoidance.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/8/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DAvoidance_hpp
#define U4DAvoidance_hpp

#include <stdio.h>
#include "U4DSeek.h"

namespace U4DEngine {
 
    /**
     @ingroup artificialintelligence
     @brief The U4DAvoidance class implements AI steering Avoidance behavior
     */
    class U4DAvoidance:public U4DSeek {
        
    private:
        
        /**
         @brief parameter used for collision
         */
        float timeParameter;
        
    public:
        
        /**
         @brief class construtor
         */
        U4DAvoidance();
        
        /**
         @brief class destructor
         */
        ~U4DAvoidance();
        
        /**
         @brief Computes the velocity for steering
         
         @param uDynamicModel 3D model represented as the pursuer
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicModel *uDynamicModel);
        
        /**
         @brief sets the parameter used to detect collision with a plane
         
         @param uTimeParameter parameter used for collision with plane
         */
        void setTimeParameter(float uTimeParameter);
        
    };
    
}

#endif /* U4DAvoidance_hpp */
