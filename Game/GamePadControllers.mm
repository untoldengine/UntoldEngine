//
//  GamePadControllers.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "GamePadControllers.h"

#include <vector>
#include "CommonProtocols.h"
#include "GameLogic.h"
#include "U4DEntity.h"
#include "U4DCallback.h"
#include "U4DCamera.h"
#include "Earth.h"

void GamePadController::init(){
    
    //get pointer to the earth
    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
    
    U4DEngine::GAMEPADELEMENT buttonAElement=U4DEngine::padButtonA;
    
    myButtonA=new U4DEngine::U4DPadButton(buttonAElement);
    
    myButtonA->setControllerInterface(this);
    
    earth->addChild(myButtonA);
    
    //create a callback
    U4DEngine::U4DCallback<GamePadController>* buttonACallback=new U4DEngine::U4DCallback<GamePadController>;

    buttonACallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonA);

    myButtonA->setCallbackAction(buttonACallback);
    
    
    
//    joyStick=new U4DEngine::U4DJoyStick("joystick", -0.7,-0.6,"joyStickBackground.png",130,130,"joystickDriver.png",80,80);
//
//    joyStick->setControllerInterface(this);
//
//    earth->addChild(joyStick,0);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* joystickCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    joystickCallback->scheduleClassWithMethod(this, &GamePadController::actionOnJoystick);
//
//    joyStick->setCallbackAction(joystickCallback);
//
//
//    myButtonA=new U4DEngine::U4DButton("buttonA",0.3,-0.6,103,103,"ButtonA.png","ButtonAPressed.png");
//
//    myButtonA->setControllerInterface(this);
//
//    earth->addChild(myButtonA,1);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* buttonACallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    buttonACallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonA);
//
//    myButtonA->setCallbackAction(buttonACallback);
//
//
//    myButtonB=new U4DEngine::U4DButton("buttonB",0.7,-0.6,103,103,"ButtonB.png","ButtonBPressed.png");
//
//    myButtonB->setControllerInterface(this);
//
//    earth->addChild(myButtonB,2);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* buttonBCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    buttonBCallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonB);
//
//    myButtonB->setCallbackAction(buttonBCallback);
    
}

void GamePadController::actionOnButtonA(){
    
    ControllerInputMessage controllerInputMessage;

    controllerInputMessage.controllerInputType=actionButtonA;

    if (myButtonA->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(myButtonA->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;

    }
    
    sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnButtonB(){
    

}

void GamePadController::actionOnJoystick(){
    
   
}


