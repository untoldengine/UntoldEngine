//
//  U4DNumerical.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/6/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DNumerical_hpp
#define U4DNumerical_hpp

#include <stdio.h>
#include "Constants.h"


namespace U4DEngine {
    
    /**
     @ingroup mathengine
     @brief The U4DNumerical provides numerical robustness in floating point comparison, rounding errors and random number generation
     */
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
        
        /**
         @brief Method which compares if two floating value are equal using absolute comparison
         
         @param uNumber1 Floating value to compare
         @param uNumber2 Floating value to compare
         @param uEpsilon Epsilon used in comparison
         
         @return Returns true if two floating value are equal
         */
        bool areEqualAbs(float uNumber1, float uNumber2, float uEpsilon);
        
        /**
         @brief Method which compares if two floating value are equal using relative comparison
         
         @param uNumber1 Floating value to compare
         @param uNumber2 Floating value to compare
         @param uEpsilon Epsilon used in comparison
         
         @return Returns true if two floating value are equal
         */
        bool areEqualRel(float uNumber1, float uNumber2, float uEpsilon);
        
        /**
         @brief Method which compares if two floating value are equal
         
         @param uNumber1 Floating value to compare
         @param uNumber2 Floating value to compare
         @param uEpsilon Epsilon used in comparison
         
         @return Returns true if two floating value are equal
         */
        bool areEqual(float uNumber1, float uNumber2, float uEpsilon);
        
        /**
         @brief Document this
         */
        float getRandomNumberBetween(float uMinValue, float uMaxValue);
            
    };

}


#endif /* U4DNumerical_hpp */
