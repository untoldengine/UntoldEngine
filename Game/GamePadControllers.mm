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
#include "U4DCallback.h"
#include "U4DCamera.h"
#include "Earth.h"

void GamePadController::init(){
    
    
    
    
//    //get pointer to the earth
//    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
//
//    U4DEngine::GAMEPADELEMENT buttonAElement=U4DEngine::padButtonA;
//    U4DEngine::GAMEPADELEMENT buttonBElement=U4DEngine::padButtonB;
//    U4DEngine::GAMEPADELEMENT buttonXElement=U4DEngine::padButtonX;
//    U4DEngine::GAMEPADELEMENT buttonYElement=U4DEngine::padButtonY;
//    U4DEngine::GAMEPADELEMENT leftTriggerElement=U4DEngine::padLeftTrigger;
//    U4DEngine::GAMEPADELEMENT rightTriggerElement=U4DEngine::padRightTrigger;
//    U4DEngine::GAMEPADELEMENT leftShoulderElement=U4DEngine::padLeftShoulder;
//    U4DEngine::GAMEPADELEMENT rightShoulderElement=U4DEngine::padRightShoulder;
//    U4DEngine::GAMEPADELEMENT leftJoystickElement=U4DEngine::padLeftThumbstick;
//    U4DEngine::GAMEPADELEMENT rightJoystickElement=U4DEngine::padRightThumbstick;
//
//    U4DEngine::GAMEPADELEMENT dpadUpButtonElement=U4DEngine::padDPadUpButton;
//    U4DEngine::GAMEPADELEMENT dpadDownButtonElement=U4DEngine::padDPadDownButton;
//    U4DEngine::GAMEPADELEMENT dpadLeftButtonElement=U4DEngine::padDPadLeftButton;
//    U4DEngine::GAMEPADELEMENT dpadRightButtonElement=U4DEngine::padDPadRightButton;
//
//    //create the pad button object
//    myButtonA=new U4DEngine::U4DPadButton(buttonAElement);
//
//    myButtonA->setControllerInterface(this);
//
//    earth->addChild(myButtonA);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* buttonACallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    buttonACallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonA);
//
//    myButtonA->setCallbackAction(buttonACallback);
//
//
//    //set the left joystick
//
//    leftJoystick=new U4DEngine::U4DPadJoystick(leftJoystickElement);
//
//    leftJoystick->setControllerInterface(this);
//
//    earth->addChild(leftJoystick);
//
//    //create joystick callback
//
//    U4DEngine::U4DCallback<GamePadController>* leftJoystickCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    leftJoystickCallback->scheduleClassWithMethod(this, &GamePadController::actionOnLeftJoystick);
//
//    leftJoystick->setCallbackAction(leftJoystickCallback);
//
//
//    //set the right joystick
//
//    rightJoystick=new U4DEngine::U4DPadJoystick(rightJoystickElement);
//
//    rightJoystick->setControllerInterface(this);
//
//    earth->addChild(rightJoystick);
//
//    //create joystick callback
//
//    U4DEngine::U4DCallback<GamePadController>* rightJoystickCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    rightJoystickCallback->scheduleClassWithMethod(this, &GamePadController::actionOnRightJoystick);
//
//    rightJoystick->setCallbackAction(rightJoystickCallback);
//
//
//
//    //create the pad B button object
//    myButtonB=new U4DEngine::U4DPadButton(buttonBElement);
//
//    myButtonB->setControllerInterface(this);
//
//    earth->addChild(myButtonB);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* buttonBCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    buttonBCallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonB);
//
//    myButtonB->setCallbackAction(buttonBCallback);
//
//
//    //create the pad X button object
//    myButtonX=new U4DEngine::U4DPadButton(buttonXElement);
//
//    myButtonX->setControllerInterface(this);
//
//    earth->addChild(myButtonX);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* buttonXCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    buttonXCallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonX);
//
//    myButtonX->setCallbackAction(buttonXCallback);
//
//    //create the pad Y button object
//    myButtonY=new U4DEngine::U4DPadButton(buttonYElement);
//
//    myButtonY->setControllerInterface(this);
//
//    earth->addChild(myButtonY);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* buttonYCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    buttonYCallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonY);
//
//    myButtonY->setCallbackAction(buttonYCallback);
//
//    //create the pad Left Trigger object
//    myLeftTrigger=new U4DEngine::U4DPadButton(leftTriggerElement);
//
//    myLeftTrigger->setControllerInterface(this);
//
//    earth->addChild(myLeftTrigger);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* leftTriggerCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    leftTriggerCallback->scheduleClassWithMethod(this, &GamePadController::actionOnLeftTrigger);
//
//    myLeftTrigger->setCallbackAction(leftTriggerCallback);
//
//
//    //create the pad Right Trigger object
//    myRightTrigger=new U4DEngine::U4DPadButton(rightTriggerElement);
//
//    myRightTrigger->setControllerInterface(this);
//
//    earth->addChild(myRightTrigger);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* rightTriggerCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    rightTriggerCallback->scheduleClassWithMethod(this, &GamePadController::actionOnRightTrigger);
//
//    myRightTrigger->setCallbackAction(rightTriggerCallback);
//
//    //create the pad Right Shoulder object
//    myRightShoulder=new U4DEngine::U4DPadButton(rightShoulderElement);
//
//    myRightShoulder->setControllerInterface(this);
//
//    earth->addChild(myRightShoulder);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* rightShoulderCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    rightShoulderCallback->scheduleClassWithMethod(this, &GamePadController::actionOnRightShoulder);
//
//    myRightShoulder->setCallbackAction(rightShoulderCallback);
//
//    //create the pad left Shoulder object
//    myLeftShoulder=new U4DEngine::U4DPadButton(leftShoulderElement);
//
//    myLeftShoulder->setControllerInterface(this);
//
//    earth->addChild(myLeftShoulder);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* leftShoulderCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    leftShoulderCallback->scheduleClassWithMethod(this, &GamePadController::actionOnLeftShoulder);
//
//    myLeftShoulder->setCallbackAction(leftShoulderCallback);
//
//    //create the pad d-pad up object
//    myDPadButtonUp=new U4DEngine::U4DPadButton(dpadUpButtonElement);
//
//    myDPadButtonUp->setControllerInterface(this);
//
//    earth->addChild(myDPadButtonUp);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* dPadUpButtonCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    dPadUpButtonCallback->scheduleClassWithMethod(this, &GamePadController::actionOnDPadUpButton);
//
//    myDPadButtonUp->setCallbackAction(dPadUpButtonCallback);
//
//    //create the pad d-pad down object
//    myDPadButtonDown=new U4DEngine::U4DPadButton(dpadDownButtonElement);
//
//    myDPadButtonDown->setControllerInterface(this);
//
//    earth->addChild(myDPadButtonDown);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* dPadDownButtonCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    dPadDownButtonCallback->scheduleClassWithMethod(this, &GamePadController::actionOnDPadDownButton);
//
//    myDPadButtonDown->setCallbackAction(dPadDownButtonCallback);
//
//    //create the pad d-pad left object
//    myDPadButtonLeft=new U4DEngine::U4DPadButton(dpadLeftButtonElement);
//
//    myDPadButtonLeft->setControllerInterface(this);
//
//    earth->addChild(myDPadButtonLeft);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* dPadLeftButtonCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    dPadLeftButtonCallback->scheduleClassWithMethod(this, &GamePadController::actionOnDPadLeftButton);
//
//    myDPadButtonLeft->setCallbackAction(dPadLeftButtonCallback);
//
//    //create the pad d-pad right object
//    myDPadButtonRight=new U4DEngine::U4DPadButton(dpadRightButtonElement);
//
//    myDPadButtonRight->setControllerInterface(this);
//
//    earth->addChild(myDPadButtonRight);
//
//    //create a callback
//    U4DEngine::U4DCallback<GamePadController>* dPadRightButtonCallback=new U4DEngine::U4DCallback<GamePadController>;
//
//    dPadRightButtonCallback->scheduleClassWithMethod(this, &GamePadController::actionOnDPadRightButton);
//
//    myDPadButtonRight->setCallbackAction(dPadRightButtonCallback);
}

void GamePadController::actionOnButtonA(){
    
//    ControllerInputMessage controllerInputMessage;
//
//    controllerInputMessage.controllerInputType=actionButtonA;
//
//    if (myButtonA->getIsPressed()) {
//
//        controllerInputMessage.controllerInputData=buttonPressed;
//
//    }else if(myButtonA->getIsReleased()){
//
//        controllerInputMessage.controllerInputData=buttonReleased;
//
//    }
//
//    sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnButtonB(){
    
//    ControllerInputMessage controllerInputMessage;
//
//    controllerInputMessage.controllerInputType=actionButtonB;
//
//    if (myButtonB->getIsPressed()) {
//
//        controllerInputMessage.controllerInputData=buttonPressed;
//
//    }else if(myButtonB->getIsReleased()){
//
//        controllerInputMessage.controllerInputData=buttonReleased;
//
//    }
//
//    sendUserInputUpdate(&controllerInputMessage);

}

void GamePadController::actionOnButtonX(){
    
//    ControllerInputMessage controllerInputMessage;
//
//    controllerInputMessage.controllerInputType=actionButtonX;
//
//    if (myButtonX->getIsPressed()) {
//
//        controllerInputMessage.controllerInputData=buttonPressed;
//
//        std::cout<<"Button X Pressed"<<std::endl;
//
//    }else if(myButtonX->getIsReleased()){
//
//        controllerInputMessage.controllerInputData=buttonReleased;
//
//        std::cout<<"Button X Released"<<std::endl;
//
//    }
//
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnButtonY(){
    
//    ControllerInputMessage controllerInputMessage;
//
//    controllerInputMessage.controllerInputType=actionButtonY;
//
//    if (myButtonY->getIsPressed()) {
//
//        controllerInputMessage.controllerInputData=buttonPressed;
//
//        std::cout<<"Button Y Pressed"<<std::endl;
//
//    }else if(myButtonY->getIsReleased()){
//
//        controllerInputMessage.controllerInputData=buttonReleased;
//
//        std::cout<<"Button Y Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnLeftTrigger(){
    
//    if (myLeftTrigger->getIsPressed()) {
//
//        std::cout<<"Left Trigger Pressed"<<std::endl;
//
//    }else if(myLeftTrigger->getIsReleased()){
//
//        std::cout<<"Left Trigger Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnRightTrigger(){
    
//    if (myRightTrigger->getIsPressed()) {
//
//        std::cout<<"right Trigger Pressed"<<std::endl;
//
//    }else if(myRightTrigger->getIsReleased()){
//
//
//        std::cout<<"right trigger Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnLeftShoulder(){
    
//    if (myLeftShoulder->getIsPressed()) {
//
//        std::cout<<"Left Shoulder Pressed"<<std::endl;
//
//    }else if(myLeftShoulder->getIsReleased()){
//
//        std::cout<<"Left Shoulder Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnRightShoulder(){
    
//    if (myRightShoulder->getIsPressed()) {
//
//        std::cout<<"right Shoulder Pressed"<<std::endl;
//
//    }else if(myRightShoulder->getIsReleased()){
//
//
//        std::cout<<"right shoulder Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnDPadUpButton(){
    
//    if (myDPadButtonUp->getIsPressed()) {
//
//        std::cout<<"D-Pad Up Pressed"<<std::endl;
//
//    }else if(myDPadButtonUp->getIsReleased()){
//
//
//        std::cout<<"D-Pad Up Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnDPadDownButton(){
    
//    if (myDPadButtonDown->getIsPressed()) {
//
//        std::cout<<"D-Pad Down Pressed"<<std::endl;
//
//    }else if(myDPadButtonDown->getIsReleased()){
//
//
//        std::cout<<"D-Pad Down Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnDPadLeftButton(){
    
//    if (myDPadButtonLeft->getIsPressed()) {
//
//        std::cout<<"D-Pad Left Pressed"<<std::endl;
//
//    }else if(myDPadButtonLeft->getIsReleased()){
//
//
//        std::cout<<"D-Pad Left Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnDPadRightButton(){
    
//    if (myDPadButtonRight->getIsPressed()) {
//
//        std::cout<<"D-Pad Right Pressed"<<std::endl;
//
//    }else if(myDPadButtonRight->getIsReleased()){
//
//
//        std::cout<<"D-Pad Right Released"<<std::endl;
//    }
    
    //sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnLeftJoystick(){
    
//    ControllerInputMessage controllerInputMessage;
//
//    controllerInputMessage.controllerInputType=actionJoystick;
//
//    if (leftJoystick->getIsActive()) {
//
//        controllerInputMessage.controllerInputData=joystickActive;
//
//        U4DEngine::U4DVector3n joystickDirection=leftJoystick->getDataPosition();
//
//        joystickDirection.z=joystickDirection.y;
//
//        joystickDirection.y=0;
//
//        joystickDirection.normalize();
//
//
//        if (leftJoystick->getDirectionReversal()) {
//
//            controllerInputMessage.joystickChangeDirection=true;
//
//        }else{
//
//            controllerInputMessage.joystickChangeDirection=false;
//
//        }
//
//        controllerInputMessage.joystickDirection=joystickDirection;
//
//    }else {
//
//        controllerInputMessage.controllerInputData=joystickInactive;
//
//    }
//
//    sendUserInputUpdate(&controllerInputMessage);
    
}

void GamePadController::actionOnRightJoystick(){
    
//   ControllerInputMessage controllerInputMessage;
//
//    controllerInputMessage.controllerInputType=actionRightJoystick;
//
//    if (rightJoystick->getIsActive()) {
//
//        controllerInputMessage.controllerInputData=joystickActive;
//
//        U4DEngine::U4DVector3n joystickDirection=rightJoystick->getDataPosition();
//
//        joystickDirection.z=joystickDirection.y;
//
//        joystickDirection.y=0;
//
//        joystickDirection.normalize();
//
//
//        if (rightJoystick->getDirectionReversal()) {
//
//            controllerInputMessage.joystickChangeDirection=true;
//
//        }else{
//
//            controllerInputMessage.joystickChangeDirection=false;
//
//        }
//
//        controllerInputMessage.joystickDirection=joystickDirection;
//
//    }else {
//
//       controllerInputMessage.controllerInputData=joystickInactive;
//
//    }
//
//    sendUserInputUpdate(&controllerInputMessage);
    
}


