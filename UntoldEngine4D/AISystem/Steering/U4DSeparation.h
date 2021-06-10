//
//  U4DSeparation.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSeparation_hpp
#define U4DSeparation_hpp

#include <stdio.h>
#include <vector>
#include "U4DSeek.h"

namespace U4DEngine {
 
    /**
     @ingroup artificialintelligence
     @brief The U4DSeparation class implements AI steering separation behavior
     */
    class U4DSeparation:public U4DSeek {
        
    private:
        
        float desiredSeparation;
        
    public:
        
        /**
         @brief class construtor
         */
        U4DSeparation();
        
        /**
         @brief class destructor
         */
        ~U4DSeparation();
        
        /**
         @brief Computes the velocity for steering
         
         @param uPursuer Dynamic action represented as the pursuer
         @param uNeighborsContainer neighbors container
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicAction *uPursuer, std::vector<U4DDynamicAction*> uNeighborsContainer);
        
        /**
         @brief Sets the separation for the neighbors
         
         @param uDesiredSeparation separation desired between neighbors
         */
        void setDesiredSeparation(float uDesiredSeparation);
        
    };
    
}
#endif /* U4DSeparation_hpp */
