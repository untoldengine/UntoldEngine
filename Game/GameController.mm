//
//  GameController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
    
    //get pointer to the earth
    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
    
    joyStick=new U4DEngine::U4DJoyStick("joystick", -0.7,-0.6,"joyStickBackground.png",130,130,"joystickDriver.png",80,80);
    
    joyStick->setControllerInterface(this);
    
    earth->addChild(joyStick,-2);
    
    //create a callback
    U4DEngine::U4DCallback<GameController>* joystickCallback=new U4DEngine::U4DCallback<GameController>;
    
    joystickCallback->scheduleClassWithMethod(this, &GameController::actionOnJoystick);
    
    joyStick->setCallbackAction(joystickCallback);
    
    
    myButtonA=new U4DEngine::U4DButton("buttonA",0.3,-0.6,103,103,"ButtonA.png","ButtonAPressed.png");
    
    myButtonA->setControllerInterface(this);
    
    earth->addChild(myButtonA,-3);
    
    //create a callback
    U4DEngine::U4DCallback<GameController>* buttonACallback=new U4DEngine::U4DCallback<GameController>;
    
    buttonACallback->scheduleClassWithMethod(this, &GameController::actionOnButtonA);
    
    myButtonA->setCallbackAction(buttonACallback);
    
    
    myButtonB=new U4DEngine::U4DButton("buttonB",0.7,-0.6,103,103,"ButtonB.png","ButtonBPressed.png");
    
    myButtonB->setControllerInterface(this);
    
    earth->addChild(myButtonB,-4);
    
    //create a callback
    U4DEngine::U4DCallback<GameController>* buttonBCallback=new U4DEngine::U4DCallback<GameController>;
    
    buttonBCallback->scheduleClassWithMethod(this, &GameController::actionOnButtonB);
    
    myButtonB->setCallbackAction(buttonBCallback);
    
}

void GameController::actionOnButtonA(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonA;
    
    if (myButtonA->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(myButtonA->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
}

void GameController::actionOnButtonB(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonB;
    
    if (myButtonB->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(myButtonB->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
}

void GameController::actionOnJoystick(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionJoystick;
    
    if (joyStick->getIsActive()) {
        
        controllerInputMessage.controllerInputData=joystickActive;
        
        U4DEngine::U4DVector3n joystickDirection=joyStick->getDataPosition();
        
        joystickDirection.z=joystickDirection.y;
        
        joystickDirection.y=0;
        
        joystickDirection.normalize();
    
        
        if (joyStick->getDirectionReversal()) {
            
            controllerInputMessage.joystickChangeDirection=true;
            
        }else{
            
            controllerInputMessage.joystickChangeDirection=false;
            
        }
        
        controllerInputMessage.joystickDirection=joystickDirection;
        
    }else {
        
        controllerInputMessage.controllerInputData=joystickInactive;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
}


