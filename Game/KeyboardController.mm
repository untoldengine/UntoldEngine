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
    U4DEngine::KEYBOARDELEMENT macKeyWElement=U4DEngine::macKeyW;
    U4DEngine::KEYBOARDELEMENT macKeySElement=U4DEngine::macKeyS;
    
    U4DEngine::KEYBOARDELEMENT macKeyFElement=U4DEngine::macKeyF;
    
    U4DEngine::KEYBOARDELEMENT macKey1Element=U4DEngine::macKey1;
    
    U4DEngine::KEYBOARDELEMENT macKeyShiftElement=U4DEngine::macShiftKey;
    U4DEngine::KEYBOARDELEMENT macKeySpaceElement=U4DEngine::macSpaceKey;
    
    U4DEngine::KEYBOARDELEMENT macArrowKeysElement=U4DEngine::macArrowKey;
    U4DEngine::MOUSEELEMENT mouseLeftButtonElement=U4DEngine::mouseLeftButton;
    U4DEngine::MOUSEELEMENT mouseCursorElement=U4DEngine::mouseCursor;
    
    //create the mac key 'w' object
    macKeyW=new U4DEngine::U4DMacKey(macKeyWElement);
    
    macKeyW->setControllerInterface(this);
    
    earth->addChild(macKeyW);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeyWCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeyWCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKeyW);
    
    macKeyW->setCallbackAction(macKeyWCallback);
    
    
    //create the mac key 's' object
    macKeyS=new U4DEngine::U4DMacKey(macKeySElement);
    
    macKeyS->setControllerInterface(this);
    
    earth->addChild(macKeyS);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeySCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeySCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKeyS);
    
    macKeyS->setCallbackAction(macKeySCallback);
    
    //create the mac key 'f' object
    macKeyF=new U4DEngine::U4DMacKey(macKeyFElement);
    
    macKeyF->setControllerInterface(this);
    
    earth->addChild(macKeyF);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeyFCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeyFCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKeyF);
    
    macKeyF->setCallbackAction(macKeyFCallback);
    
    //create the mac key '1' object
    macKey1=new U4DEngine::U4DMacKey(macKey1Element);
    
    macKey1->setControllerInterface(this);
    
    earth->addChild(macKey1);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKey1Callback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKey1Callback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKey1);
    
    macKey1->setCallbackAction(macKey1Callback);
    
    //create the mac key 'a' object
    macKeyA=new U4DEngine::U4DMacKey(macKeyAElement);
    
    macKeyA->setControllerInterface(this);
    
    earth->addChild(macKeyA);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeyACallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeyACallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacKeyA);
    
    macKeyA->setCallbackAction(macKeyACallback);
    
    //create the mac key 'space' object
    macKeySpace=new U4DEngine::U4DMacKey(macKeySpaceElement);
    
    macKeySpace->setControllerInterface(this);
    
    earth->addChild(macKeySpace);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeySpaceCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeySpaceCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacSpaceKey);
    
    macKeySpace->setCallbackAction(macKeySpaceCallback);
    
    
    //create the mac key 'shift' object
    macKeyShift=new U4DEngine::U4DMacKey(macKeyShiftElement);
    
    macKeyShift->setControllerInterface(this);
    
    earth->addChild(macKeyShift);
    
    //create a callback
    U4DEngine::U4DCallback<KeyboardController>* macKeyShiftCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    macKeyShiftCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMacShiftKey);
    
    macKeyShift->setCallbackAction(macKeyShiftCallback);
    
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
    
    //create a mouse left key object

    mouseLeftButton=new U4DEngine::U4DMacMouse(mouseLeftButtonElement);
    mouseLeftButton->setControllerInterface(this);

    earth->addChild(mouseLeftButton);

    //create the left button mouse callback
    U4DEngine::U4DCallback<KeyboardController>* mouseLeftButtonCallback=new U4DEngine::U4DCallback<KeyboardController>;

    mouseLeftButtonCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMouseLeftButton);

    mouseLeftButton->setCallbackAction(mouseLeftButtonCallback);
    
    //create mouse object
    macMouseCursor=new U4DEngine::U4DMacMouse(mouseCursorElement);
    macMouseCursor->setControllerInterface(this);
    
    earth->addChild(macMouseCursor);
    
    //create the mouse callback
    U4DEngine::U4DCallback<KeyboardController>* mouseCursorCallback=new U4DEngine::U4DCallback<KeyboardController>;
    
    mouseCursorCallback->scheduleClassWithMethod(this, &KeyboardController::actionOnMouseMoved);
    
    macMouseCursor->setCallbackAction(mouseCursorCallback);
    
    
}

void KeyboardController::actionOnMacKeyW(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonW;
    
    if (macKeyW->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyW->getIsReleased()){
        
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
}

void KeyboardController::actionOnMacKeyS(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonS;
    
    if (macKeyS->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyS->getIsReleased()){
        
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
    
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
    
    controllerInputMessage.controllerInputType=actionButtonD;
    
    if (macKeyD->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyD->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
        sendUserInputUpdate(&controllerInputMessage);
}

void KeyboardController::actionOnMacKeyF(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionButtonF;
    
    if (macKeyF->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyF->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
    
}

void KeyboardController::actionOnMacKey1(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionKey1;
    
    if (macKey1->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKey1->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
    
}

void KeyboardController::actionOnMacShiftKey(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionKeyShift;
    
    if (macKeyShift->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeyShift->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
    
}

void KeyboardController::actionOnMacSpaceKey(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionKeySpace;
    
    if (macKeySpace->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(macKeySpace->getIsReleased()){
        
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
    
    controllerInputMessage.controllerInputType=actionMouseLeftTrigger;
    
    if (mouseLeftButton->getIsPressed()) {
        
        controllerInputMessage.controllerInputData=buttonPressed;
        
    }else if(mouseLeftButton->getIsReleased()){
        
        controllerInputMessage.controllerInputData=buttonReleased;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
}

void KeyboardController::actionOnMouseMoved(){
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionJoystick;
    
    if (macMouseCursor->getIsMoving()) {
        
        controllerInputMessage.controllerInputData=joystickActive;
        
        U4DEngine::U4DVector3n mousePosition=macMouseCursor->getDataPosition();
        
        U4DEngine::U4DVector3n previousMousePosition=macMouseCursor->getPreviousDataPosition();
        
        U4DEngine::U4DVector2n mouseDeltaPosition=macMouseCursor->getMouseDeltaPosition();
        
        controllerInputMessage.mousePosition=mousePosition;
        
        controllerInputMessage.previousMousePosition=previousMousePosition;
        
        controllerInputMessage.mouseDeltaPosition=mouseDeltaPosition;
        
    }else {
        
        controllerInputMessage.controllerInputData=joystickInactive;
        
    }
    
    sendUserInputUpdate(&controllerInputMessage);
    
    
    
}
