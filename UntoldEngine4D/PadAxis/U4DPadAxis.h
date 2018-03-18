//
//  U4DPadAxis.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPadAxis_hpp
#define U4DPadAxis_hpp

#include <stdio.h>
#include "CommonProtocols.h"
#include "U4DVector2n.h"


namespace U4DEngine {
    
    /**
     @brief The U4DPadAxis class is in charge of interpreting all Game Pad Axis inputs
     */
    class U4DPadAxis{
        
    private:
        
    public:
        
        /**
         @brief Axis representing the x-coordinate
         */
        float xAxis;
        
        /**
         @brief Axis representing the y-coordinate
         */
        float yAxis;
        
        /**
         @brief Axis constructor
         @param uXAxis Axis x-Coordinate
         @param uYAxis Axis y-Coordinate
         */
        U4DPadAxis(float uXAxis,float uYAxis);
        
        /**
         @brief Axis destructor
         */
        ~U4DPadAxis();
        
        /**
         @brief Method which sets the current Axis point
         
         @param uXAxis x-coordinate Axis position
         @param uYAxis y-coordinate Axis positition
         */
        void setPoint(float uXAxis,float uYAxis);
        
        /**
         @brief Method which returns the current Axis position
         
         @return Returns a 2D vector representing the current Axis position
         */
        U4DVector2n getPoint();
        
    };
    
}
#endif /* U4DPadAxis_hpp */
