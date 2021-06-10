//
//  U4DFlee.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DFlee_hpp
#define U4DFlee_hpp

#include <stdio.h>
#include "U4DSteering.h"

namespace U4DEngine {
    class U4DDynamicAction;
}

namespace U4DEngine {
    
    /**
     @ingroup artificialintelligence
     @brief The U4DFlee class implements AI steering Flee behavior
     */
    class U4DFlee:public U4DSteering {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DFlee();
        
        /**
         @brief class destructor
         */
        ~U4DFlee();
        
        /**
         @brief Computes the velocity for steering
         
         @param uAction Dynamic action represented as the pursuer
         @param uTargetPosition target position in vector format
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition);
        
    };
    
}


#endif /* U4DFlee_hpp */
