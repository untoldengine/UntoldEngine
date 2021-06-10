//
//  U4DAlign.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DAlign_hpp
#define U4DAlign_hpp

#include <stdio.h>
#include <vector>
#include "U4DSeek.h"

namespace U4DEngine {
 
    /**
     @ingroup artificialintelligence
     @brief The U4DAlign class implements AI steering separation behavior
     */
    class U4DAlign:public U4DSeek {
        
    private:
        
        float neighborDistance;
        
    public:
        
        /**
         @brief class construtor
         */
        U4DAlign();
        
        /**
         @brief class destructor
         */
        ~U4DAlign();
        
        /**
         @brief Computes the velocity for steering
         
         @param uPursuer Dynamic action represented as the pursuer
         @param uNeighborsContainer neighbors container
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicAction *uPursuer, std::vector<U4DDynamicAction*> uNeighborsContainer);
        
        /**
         @brief Sets the desired neighbor distance which will be influenced by the behavior
         
         @param uNeighborDistance Neighbor distance
         */
        void setNeighborDistance(float uNeighborDistance);
        
    };
    
}
#endif /* U4DAlign_hpp */
