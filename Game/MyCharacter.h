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
#include "UserCommonProtocols.h"

class MyCharacter:public U4DEngine::U4DGameObject{

private:
    
    U4DEngine::U4DVector3n joyStickData;
    GameEntityState entityState;
    
public:
    
    MyCharacter():joyStickData(0.0,0.0,0.0){};
    
    float x,y,z;
  
    void init(const char* uName, const char* uBlenderFile);
    
    void update(double dt);
    
    void changeState(GameEntityState uState);
    
    void setState(GameEntityState uState);
    
    GameEntityState getState();
    
    U4DEngine::U4DAnimation *walking;
    
    U4DEngine::U4DAnimation *jump;
    
    
    inline void setJoystickData(U4DEngine::U4DVector3n& uData){joyStickData=uData;}
    
};

#endif /* defined(__UntoldEngine__MyCharacter__) */
