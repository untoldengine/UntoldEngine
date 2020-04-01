//
//  GameController.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__GameController__
#define __UntoldEngine__GameController__

#include <iostream>
#include "U4DTouchesController.h"
#include "U4DVector3n.h"
#include "UserCommonProtocols.h"

class GameController:public U4DEngine::U4DTouchesController{
  
private:

    U4DEngine::U4DJoyStick *joyStick;
    U4DEngine::U4DButton *myButtonA;
    U4DEngine::U4DButton *myButtonB;
    
public:
    
    GameController(){};
    
    
    ~GameController(){};
    
    void init();
    
    void actionOnButtonA();
    
    void actionOnButtonB();
    
    void actionOnJoystick();

};

#endif /* defined(__UntoldEngine__GameController__) */
