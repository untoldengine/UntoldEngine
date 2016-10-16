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
#include "CommonProtocols.h"


class MyCharacter:public U4DEngine::U4DGameObject{

public:
    
    MyCharacter(){};
    
    float x,y,z;
  
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(U4DEngine::ENTITYDATASTATE uEntityDataState);
    
    U4DEngine::U4DAnimation *anim;
    
    int replay;
    
private:
   
    
};

#endif /* defined(__UntoldEngine__MyCharacter__) */
