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
#include "U4DTouches.h"

class GameController:public U4DEngine::U4DTouchesController{
  
private:

    
public:
    
    GameController(){};
    
    
    ~GameController(){};
    
    void init();
    
    void actionOnButtonA();
    
    void actionOnButtonB();
    
    void actionOnJoystick();

};

#endif /* defined(__UntoldEngine__GameController__) */
