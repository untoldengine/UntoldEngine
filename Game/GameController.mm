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
    
    joyStick=new U4DEngine::U4DJoyStick("joystick", -0.7,-0.6,"joyStickBackground.png",230,230,"joystickDriver.png",140,140);
    
    joyStick->setControllerInterface(this);
    
    add(joyStick);
    
    myButton=new U4DEngine::U4DButton("buttonA",0.3,-0.6,170,170,"ButtonA.png","ButtonAPressed.png");
    
    myButton->setControllerInterface(this);
    
    add(myButton);
    
    
    myButtonB=new U4DEngine::U4DButton("buttonB",0.7,-0.6,170,170,"ButtonB.png","ButtonBPressed.png");
    
    myButtonB->setControllerInterface(this);
    
    add(myButtonB);
    
}


