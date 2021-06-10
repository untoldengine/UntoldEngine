//
//  U4DSeek.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSeek_hpp
#define U4DSeek_hpp

#include <stdio.h>
#include "U4DSteering.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    class U4DDynamicAction;
}

namespace U4DEngine{
 
    /**
     @ingroup artificialintelligence
     @brief The U4DSeek class implements AI steering Seek behavior
     */
    class U4DSeek:public U4DSteering {
        
    private:
        
    public:
        
        /**
         @brief class constructor
         */
        U4DSeek();
        
        /**
         @brief class destructor
         */
        ~U4DSeek();
        
        /**
         @brief Computes the velocity for steering
         
         @param uAction Dynamic action represented as the pursuer
         @param uTargetPosition target position in vector format
         @return velocity vector to apply to 3D model
         */
        U4DVector3n getSteering(U4DDynamicAction *uAction, U4DVector3n &uTargetPosition);
        
    };
    
}

#endif /* U4DSeek_hpp */
