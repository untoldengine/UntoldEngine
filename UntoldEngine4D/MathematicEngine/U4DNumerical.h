//
//  U4DNumerical.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/6/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DNumerical_hpp
#define U4DNumerical_hpp

#include <stdio.h>
#include "Constants.h"

namespace U4DEngine {
    
    /// The U4DNumerical provides numerical robustness in floating point comparison and rounding errors
    class U4DNumerical {
        
    private:
        
    public:
        
        /**
         @brief Default constructor for U4DNumerical
         */
        U4DNumerical();
        
        /**
         @brief Default destructor for U4DNumerical
         */
        ~U4DNumerical();
        

        bool areEqualAbs(float uNumber1, float uNumber2, float uEpsilon);
        
        bool areEqualRel(float uNumber1, float uNumber2, float uEpsilon);
        
        bool areEqual(float uNumber1, float uNumber2, float uEpsilon);
        
    };

}


#endif /* U4DNumerical_hpp */
