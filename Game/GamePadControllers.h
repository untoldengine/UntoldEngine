//
//  GamePadControllers.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#ifndef GamePadControllers_hpp
#define GamePadControllers_hpp

#include <stdio.h>
#include "U4DGamePadController.h"
#include "U4DVector3n.h"
#include "UserCommonProtocols.h"
#include "U4DPadButton.h"


class GamePadController:public U4DEngine::U4DGamepadController{
    
private:
    
    U4DEngine::U4DPadButton *myButtonA;
    
public:
    
    GamePadController(){};
    
    
    ~GamePadController(){};
    
    void init();
    
    void actionOnButtonA();
    
    void actionOnButtonB();
    
    void actionOnJoystick();
    
};
#endif /* GamePadControllers_hpp */
