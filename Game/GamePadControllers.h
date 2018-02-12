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
#include "U4DPadJoystick.h"

class GamePadController:public U4DEngine::U4DGamepadController{
    
private:
    
    U4DEngine::U4DPadButton *myButtonA;
    U4DEngine::U4DPadButton *myButtonB;
    U4DEngine::U4DPadButton *myButtonX;
    U4DEngine::U4DPadButton *myButtonY;
    U4DEngine::U4DPadButton *myLeftTrigger;
    U4DEngine::U4DPadButton *myRightTrigger;
    U4DEngine::U4DPadButton *myLeftShoulder;
    U4DEngine::U4DPadButton *myRightShoulder;
    U4DEngine::U4DPadButton *myDPadButtonUp;
    U4DEngine::U4DPadButton *myDPadButtonDown;
    U4DEngine::U4DPadButton *myDPadButtonLeft;
    U4DEngine::U4DPadButton *myDPadButtonRight;
    U4DEngine::U4DPadJoystick *leftJoystick;
    U4DEngine::U4DPadJoystick *rightJoystick;
    
public:
    
    GamePadController(){};
    
    
    ~GamePadController(){};
    
    void init();
    
    void actionOnButtonA();
    
    void actionOnButtonB();
    
    void actionOnButtonX();
    
    void actionOnButtonY();
    
    void actionOnLeftTrigger();
    
    void actionOnRightTrigger();
    
    void actionOnLeftShoulder();
    
    void actionOnRightShoulder();
    
    void actionOnDPadUpButton();
    
    void actionOnDPadDownButton();
    
    void actionOnDPadLeftButton();
    
    void actionOnDPadRightButton();
    
    void actionOnLeftJoystick();
    
    void actionOnRightJoystick();
    
};
#endif /* GamePadControllers_hpp */
