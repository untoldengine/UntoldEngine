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
    
class U4DTouches{
  
private:
public:
    float xTouch,yTouch;

    U4DTouches(float uXTouch,float uYTouch):xTouch(uXTouch),yTouch(uYTouch){};
    
    ~U4DTouches(){}
    
    inline void setPoint(float uXTouch,float uYTouch){
        xTouch=uXTouch;
        yTouch=uYTouch;
    }
    
    inline U4DVector2n getPoint(){
        U4DVector2n touch;
        
        touch.x=this->xTouch;
        touch.y=this->yTouch;

        return touch;
    }
};
    
}

#endif /* defined(__UntoldEngine__Touches__) */
