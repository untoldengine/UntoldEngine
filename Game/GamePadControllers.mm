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
    U4DEngine::GAMEPADELEMENT leftJoystickElement=U4DEngine::padLeftThumbstick;
    
    //create the pad button object
    myButtonA=new U4DEngine::U4DPadButton(buttonAElement);
    
    myButtonA->setControllerInterface(this);
    
    earth->addChild(myButtonA);
    
    //create a callback
    U4DEngine::U4DCallback<GamePadController>* buttonACallback=new U4DEngine::U4DCallback<GamePadController>;

    buttonACallback->scheduleClassWithMethod(this, &GamePadController::actionOnButtonA);

    myButtonA->setCallbackAction(buttonACallback);
    
    
    //set the left joystick
    
    leftJoystick=new U4DEngine::U4DPadJoystick(leftJoystickElement);
    
    leftJoystick->setControllerInterface(this);
    
    earth->addChild(leftJoystick);
    
    //create joystick callback
    
    U4DEngine::U4DCallback<GamePadController>* leftJoystickCallback=new U4DEngine::U4DCallback<GamePadController>;
    
    leftJoystickCallback->scheduleClassWithMethod(this, &GamePadController::actionOnJoystick);
    
    leftJoystick->setCallbackAction(leftJoystickCallback);
    
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
    
    ControllerInputMessage controllerInputMessage;
    
    controllerInputMessage.controllerInputType=actionJoystick;
    
    if (leftJoystick->getIsActive()) {
        
        controllerInputMessage.controllerInputData=joystickActive;
        
        U4DEngine::U4DVector3n joystickDirection=leftJoystick->getDataPosition();
        
        joystickDirection.z=joystickDirection.y;
        
        joystickDirection.y=0;
        
        joystickDirection.normalize();
        
        
        if (leftJoystick->getDirectionReversal()) {
            
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


