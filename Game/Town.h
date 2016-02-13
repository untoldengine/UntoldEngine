//
//  Town.h
//  UntoldEngine
//
//  Created by Harold Serrano on 4/20/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__Town__
#define __UntoldEngine__Town__

#include <iostream>
#include <string>
#include "U4DGameObject.h"


class Town:public U4DEngine::U4DGameObject{
    
public:
    
    Town(){};
    
    float x,y,z;
    
    void init(const char* uName,float xPosition,float yPosition, float zPosition);
    
    void update(double dt);
    
    
private:
    
    
};


#endif /* defined(__UntoldEngine__Town__) */
