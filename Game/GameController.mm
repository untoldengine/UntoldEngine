//
//  GameController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameController.h"
#include <vector>
#include "CommonProtocols.h"
#include "GameLogic.h"
#include "U4DEntity.h"
#include "U4DCallback.h"
#include "U4DButton.h"
#include "U4DCamera.h"
#include "U4DJoyStick.h"
#include "Earth.h"

void GameController::init(){
    
    joyStick=new U4DEngine::U4DJoyStick("myJoystick", -0.5,-0.5,"joyStickBackground.png",124,124,"joystickDriver.png",76,76);
    
    joyStick->setControllerInterface(this);
    
    add(joyStick);
    
    myButton=new U4DEngine::U4DButton(0.5,-0.5,102,102,"ButtonA.png","ButtonAPressed.png");
    
    myButton->setControllerInterface(this);
    
    add(myButton);
    
    
    myButtonB=new U4DEngine::U4DButton(0.2,-0.5,102,102,"ButtonB.png","ButtonBPressed.png");
    
    myButtonB->setControllerInterface(this);
    
    add(myButtonB);
    
}


