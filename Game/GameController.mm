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
    
    earth->addChild(joyStick,0);
    
    //create a callback
    U4DEngine::U4DCallback<GameController>* joystickCallback=new U4DEngine::U4DCallback<GameController>;
    
    joystickCallback->scheduleClassWithMethod(this, &GameController::actionOnJoystick);
    
    joyStick->setCallbackAction(joystickCallback);
    
    
    myButtonA=new U4DEngine::U4DButton("buttonA",0.3,-0.6,103,103,"ButtonA.png","ButtonAPressed.png");
    
    myButtonA->setControllerInterface(this);
    
    earth->addChild(myButtonA,1);
    
    //create a callback
    U4DEngine::U4DCallback<GameController>* buttonACallback=new U4DEngine::U4DCallback<GameController>;
    
    buttonACallback->scheduleClassWithMethod(this, &GameController::actionOnButtonA);
    
    myButtonA->setCallbackAction(buttonACallback);
    
    
    myButtonB=new U4DEngine::U4DButton("buttonB",0.7,-0.6,103,103,"ButtonB.png","ButtonBPressed.png");
    
    myButtonB->setControllerInterface(this);
    
    earth->addChild(myButtonB,2);
    
    //create a callback
    U4DEngine::U4DCallback<GameController>* buttonBCallback=new U4DEngine::U4DCallback<GameController>;
    
    buttonBCallback->scheduleClassWithMethod(this, &GameController::actionOnButtonB);
    
    myButtonB->setCallbackAction(buttonBCallback);
    
}

void GameController::actionOnButtonA(){
    
    TouchInputMessage touchInputMessage;
    
    touchInputMessage.touchInputType=actionButtonA;
    
    if (myButtonA->getIsPressed()) {
        
        touchInputMessage.touchInputData=buttonPressed;
        
    }else if(myButtonA->getIsReleased()){
        
        touchInputMessage.touchInputData=buttonReleased;
        
    }
    
    sendTouchUpdate(&touchInputMessage);
}

void GameController::actionOnButtonB(){
    
    TouchInputMessage touchInputMessage;
    
    touchInputMessage.touchInputType=actionButtonB;
    
    if (myButtonB->getIsPressed()) {
        
        touchInputMessage.touchInputData=buttonPressed;
        
    }else if(myButtonB->getIsReleased()){
        
        touchInputMessage.touchInputData=buttonReleased;
        
    }
    
    sendTouchUpdate(&touchInputMessage);
}

void GameController::actionOnJoystick(){
    
    TouchInputMessage touchInputMessage;
    
    touchInputMessage.touchInputType=actionJoystick;
    
    if (joyStick->getIsActive()) {
        
        touchInputMessage.touchInputData=joystickActive;
        
        U4DEngine::U4DVector3n joystickDirection=joyStick->getDataPosition();
        
        joystickDirection.z=joystickDirection.y;
        
        joystickDirection.y=0;
        
        joystickDirection.normalize();
    
        
        if (joyStick->getDirectionReversal()) {
            
            touchInputMessage.joystickChangeDirection=true;
            
        }else{
            
            touchInputMessage.joystickChangeDirection=false;
            
        }
        
        touchInputMessage.joystickDirection=joystickDirection;
        
    }else {
        
        touchInputMessage.touchInputData=joystickInactive;
        
    }
    
    sendTouchUpdate(&touchInputMessage);
}


