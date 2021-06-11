//
//  U4DPursuit.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPursuit_hpp
#define U4DPursuit_hpp

#include <stdio.h>
#include "U4DSeek.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    class U4DDynamicAction;
}

namespace U4DEngine{
    
    /**
     @ingroup artificialintelligence
     @brief The U4DPursuit class implements AI steering Pursuit behavior
     */
    class U4DPursuit:public U4DSeek {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DPursuit();
        
        /**
         @brief class destructor
         */
        ~U4DPursuit();
        
        /**
         @brief Computes the velocity for steering
         
         @param uPursuer Dynamic action represented as the pursuer
         @param uEvader Dynamic action represented as the evader. Also known as the target
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicAction *uPursuer, U4DDynamicAction *uEvader);
        
    };
    
}
#endif /* U4DPursuit_hpp */
