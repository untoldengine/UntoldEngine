//
//  U4DCohesion.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/14/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCohesion_hpp
#define U4DCohesion_hpp

#include <stdio.h>
#include <vector>
#include "U4DArrive.h"

namespace U4DEngine {
 
    /**
     @ingroup artificialintelligence
     @brief The U4DCohesion class implements AI steering separation behavior
     */
    class U4DCohesion:public U4DArrive {
        
    private:
        
        float neighborDistance;
        
    public:
        
        /**
         @brief class construtor
         */
        U4DCohesion();
        
        /**
         @brief class destructor
         */
        ~U4DCohesion();
        
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
#endif /* U4DCohesion_hpp */
