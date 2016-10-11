//
//  MyCharacter.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__MyCharacter__
#define __UntoldEngine__MyCharacter__

#include <iostream>
#include <string>
#include "U4DGameObject.h"


class MyCharacter:public U4DEngine::U4DGameObject{

public:
    
    MyCharacter(){};
    
    float x,y,z;
  
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    U4DEngine::U4DAnimation *anim;
    
private:
   
    
};

#endif /* defined(__UntoldEngine__MyCharacter__) */
