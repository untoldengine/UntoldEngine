//
//  Touches.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DTouches__
#define __UntoldEngine__U4DTouches__

#include <iostream>
#include "CommonProtocols.h"
#include "U4DVector2n.h"


namespace U4DEngine {

/**
 @brief The U4DTouches class is in charge of interpreting all touches
 */
class U4DTouches{
  
private:
    
public:

    /**
     @brief Touch representing the x-coordinate
     */
    float xTouch;
    
    /**
     @brief Touch representing the y-coordinate
     */
    float yTouch;

    /**
     @brief Touch constructor
     @param uXTouch Touch x-Coordinate
     @param uYTouch Touch y-Coordinate
     */
    U4DTouches(float uXTouch,float uYTouch);
    
    /**
     @brief Touch destructor
     */
    ~U4DTouches();
    
    /**
     @brief Method which sets the current touch point
     
     @param uXTouch x-coordinate touch position
     @param uYTouch y-coordinate touch positition
     */
    void setPoint(float uXTouch,float uYTouch);
    
    /**
     @brief Method which returns the current touch position
     
     @return Returns a 2D vector representing the current touch position
     */
    U4DVector2n getPoint();
    
};
    
}

#endif /* defined(__UntoldEngine__Touches__) */
