//
//  U4DTrigonometry.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/14/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#ifndef U4DTrigonometry_hpp
#define U4DTrigonometry_hpp

#include <stdio.h>


namespace U4DEngine {

    /**
     @ingroup mathengine
     @brief The U4DTrigonometry class provides trigonometrical computations such as degress to radius conversion
     */
    class U4DTrigonometry{
        
    private:
        
    public:
        
        /**
         @brief Default constructor for the U4DTrigonometry class
         */
        U4DTrigonometry();
        
        /**
         @brief Default destructor for the U4DTrigonometry class
         */
        ~U4DTrigonometry();
        
        /**
         @brief Method which converts the given angle from degrees to radian
         
         @param uAngle Angle to convert
         
         @return Returns the radian value of the given angle
         */
        float degreesToRad(float uAngle);
        
        /**
         @brief Method which converts the given angle from radian to degrees
         
         @param uAngle Angle to convert
         
         @return Returns the degree value fo the given angle
         */
        float radToDegrees(float uAngle);
        
        /*
         @todo document this
         */
        double safeAcos(double x);
        
        /*
         @todo document this
         */
        double convertToPositiveAngle(float uAngle);
    };
}

#endif /* U4DTrigonometry_hpp */
