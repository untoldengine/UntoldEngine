//
//  Touches.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DTouches.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DTouches::U4DTouches(float uXTouch,float uYTouch):xTouch(uXTouch),yTouch(uYTouch){}
    
    U4DTouches::~U4DTouches(){}
    
    void U4DTouches::setPoint(float uXTouch,float uYTouch){
        xTouch=uXTouch;
        yTouch=uYTouch;
    }
    
    U4DVector2n U4DTouches::getPoint(){
        U4DVector2n touch;
        
        touch.x=this->xTouch;
        touch.y=this->yTouch;
        
        return touch;
    }
    
}