//
//  KeyboardController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "KeyboardController.h"
#include "CommonProtocols.h"
#include "GameLogic.h"
#include "U4DEntity.h"
#include "U4DCallback.h"
#include "U4DCamera.h"
#include "Earth.h"

void KeyboardController::init(){
    
    //get pointer to the earth
    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
    
    U4DEngine::KEYBOARDELEMENT macKeyAElement=U4DEngine::macKeyA;
    U4DEngine::KEYBOARDELEMENT macKeyDElement=U4DEngine::macKeyD;
    U4DEngine::KEYBOARDELEMENT macArrowKeysElement=U4DEngine::macArrowKey;
    U4DEngine::MOUSEELEMENT mouseLeftButtonElement=U4DEngine::mouseLeftButton;
    
    //create the mac key 'a' object
    macKeyA=new U4DEngine::U4DMacKey(macKeyAElement);
    
    macKeyA->setControllerInterface(this);
    
    earth->addChild(macKeyA);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeyACallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeyACallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKeyA);
    
    macKeyA->setCallbackAction(macKeyACallback);
    
    //create the mac key 'd' object
    macKeyD=new U4DEngine::U4DMacKey(macKeyDElement);
    
    macKeyD->setControllerInterface(this);
    
    earth->addChild(macKeyD);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeyDCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeyDCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKeyD);
    
    macKeyD->setCallbackAction(macKeyDCallback);
    
    //create the arrow keys object
    
    macArrowKeys=new U4DEngine::U4DMacArrowKey(macArrowKeysElement);
    
    macArrowKeys->setControllerInterface(this);
    
    earth->addChild(macArrowKeys);
    
    //create joystick callback
    
    U4DEngine::U4DCallback<KeyboardController>* macArrowKeysCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macArrowKeysCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnArrowKeys);
    
    macArrowKeys->setCallbackAction(macArrowKeysCallback);
    
    //create a mouse object
    
    mouseLeftButton=new U4DEngine::U4DMacMouse(mouseLeftButtonElement);
    mouseLeftButton->setControllerInterface(this);
    
    earth->addChild(mouseLeftButton);
    
    //create the mouse callback
    U4DEngine::U4DCallback<KeyboardController>* mouseLeftButtonCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    mouseLeftButtonCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMouseLeftButton);
    
    mouseLeftButton->setCallbackAction(mouseLeftButtonCallback);
    
}

void KeyboardController::actionOnMacKeyA(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonA;
    
    if (macKeyA->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyA->getIsReleased()){
        
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
}

void KeyboardController::actionOnMacKeyD(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonB;
    
    if (macKeyD->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyD->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
        sendUserInputUpdate(&controllerInputMessage);
}

void KeyboardController::actionOnArrowKeys(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionJoystick;
    
    if (macArrowKeys->getIsActive()) {
        
        controllerInputMessage.controllerInputData=joystickActive;

        U4DEngine::U4DVector3n joystickDirection=macArrowKeys->getDataPosition();

        joystickDirection.z=joystickDirection.y;

        joystickDirection.y=0;

        joystickDirection.normalize();

        if (macArrowKeys->getDirectionReversal()) {

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

void KeyboardController::actionOnMouseLeftButton(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionJoystick;
    
    if (mouseLeftButton->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=joystickActive;
        
        U4DEngine::U4DVector3n joystickDirection=mouseLeftButton->getDataPosition();
        
        joystickDirection.z=joystickDirection.y;
        
        joystickDirection.y=0;
        
        joystickDirection.normalize();
        
        if (mouseLeftButton->getDirectionReversal()) {
            
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
