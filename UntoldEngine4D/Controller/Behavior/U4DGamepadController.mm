//
//  U4DGamepadController.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/7/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DGamepadController.h"


namespace U4DEngine {
    
    //constructor
    U4DGamepadController::U4DGamepadController(){}
    
    //destructor
    U4DGamepadController::~U4DGamepadController(){}

    void U4DGamepadController::init(){
        
        //Buttons
        buttonA=new U4DPadButton(U4DEngine::padButtonA, this);
        buttonB=new U4DPadButton(U4DEngine::padButtonB,this);
        buttonX=new U4DPadButton(U4DEngine::padButtonX,this);
        buttonY=new U4DPadButton(U4DEngine::padButtonY,this);
        
        //trigger
        leftTrigger=new U4DPadButton(U4DEngine::padLeftTrigger,this);
        rightTrigger=new U4DPadButton(U4DEngine::padRightTrigger,this);
        
        //shoulder
        leftShoulder=new U4DPadButton(U4DEngine::padLeftShoulder,this);
        rightShoulder=new U4DPadButton(U4DEngine::padRightShoulder,this);
        
        //d-pad
        dPadButtonUp=new U4DPadButton(U4DEngine::padDPadUpButton,this);
        dPadButtonDown=new U4DPadButton(U4DEngine::padDPadDownButton,this);
        dPadButtonLeft=new U4DPadButton(U4DEngine::padDPadLeftButton,this);
        dPadButtonRight=new U4DPadButton(U4DEngine::padDPadRightButton,this);
        
        //Analog Joystick
        leftJoystick=new U4DPadJoystick(U4DEngine::padLeftThumbstick, this);
        rightJoystick=new U4DPadJoystick(U4DEngine::padRightThumbstick, this);
        
        //buttons
        registerInputEntity(buttonA);
        registerInputEntity(buttonB);
        registerInputEntity(buttonX);
        registerInputEntity(buttonY);
        
        //triggers
        registerInputEntity(leftTrigger);
        registerInputEntity(rightTrigger);
        
        //shoulder
        registerInputEntity(leftShoulder);
        registerInputEntity(rightShoulder);
        
        //d-pad
        registerInputEntity(dPadButtonUp);
        registerInputEntity(dPadButtonDown);
        registerInputEntity(dPadButtonRight);
        registerInputEntity(dPadButtonLeft);
        
        //analog sticks
        registerInputEntity(leftJoystick);
        registerInputEntity(rightJoystick);
        
    }
    
    void U4DGamepadController::getUserInputData(GCExtendedGamepad *gamepad, GCControllerElement *element){
        
        U4DVector2n pos(0.0,0.0);
        
        //BUTTONS
        
        // A button
        if (gamepad.buttonA == element && gamepad.buttonA.isPressed) {
            
            changeState(U4DEngine::padButtonA, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.buttonA == element && !gamepad.buttonA.isPressed){

            changeState(U4DEngine::padButtonA, U4DEngine::padButtonReleased,pos);
            
        }

        // B button
        if (gamepad.buttonB == element && gamepad.buttonB.isPressed) {

            changeState(U4DEngine::padButtonB, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.buttonB == element && !gamepad.buttonB.isPressed){

            changeState(U4DEngine::padButtonB, U4DEngine::padButtonReleased,pos);
            
        }

        // X button
        if (gamepad.buttonX == element && gamepad.buttonX.isPressed) {
            
            changeState(U4DEngine::padButtonX, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.buttonX == element && !gamepad.buttonX.isPressed){
            
            changeState(U4DEngine::padButtonX, U4DEngine::padButtonReleased,pos);
        }

        // Y button
        if (gamepad.buttonY == element && gamepad.buttonY.isPressed) {
            
            changeState(U4DEngine::padButtonY, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.buttonY == element && !gamepad.buttonY.isPressed){
            
            changeState(U4DEngine::padButtonY, U4DEngine::padButtonReleased,pos);
            
        }
        
        //TRIGGER AND SHOULDERS
        
        // left trigger
        if (gamepad.leftTrigger == element && gamepad.leftTrigger.isPressed) {
            
            changeState(U4DEngine::padLeftTrigger, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.leftTrigger == element && !gamepad.leftTrigger.isPressed){
            
            changeState(U4DEngine::padLeftTrigger, U4DEngine::padButtonReleased,pos);
            
        }

        // right trigger
        if (gamepad.rightTrigger == element && gamepad.rightTrigger.isPressed) {
            
            changeState(U4DEngine::padRightTrigger, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.rightTrigger == element && !gamepad.rightTrigger.isPressed){

            changeState(U4DEngine::padRightTrigger, U4DEngine::padButtonReleased,pos);
        }

        // left shoulder button
        if (gamepad.leftShoulder == element && gamepad.leftShoulder.isPressed) {
            
            changeState(U4DEngine::padLeftShoulder, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.leftShoulder == element && !gamepad.leftShoulder.isPressed){

            changeState(U4DEngine::padLeftShoulder, U4DEngine::padButtonReleased,pos);
        
        }

        // right shoulder button
        if (gamepad.rightShoulder == element && gamepad.rightShoulder.isPressed) {
            
            changeState(U4DEngine::padRightShoulder, U4DEngine::padButtonPressed,pos);
            
        }else if(gamepad.rightShoulder == element && !gamepad.rightShoulder.isPressed){

            changeState(U4DEngine::padRightShoulder, U4DEngine::padButtonReleased,pos);
            
        }
        
        //D-PAD

        if (gamepad.dpad == element) {

            if (gamepad.dpad.up.isPressed) {
                
                changeState(U4DEngine::padDPadUpButton, U4DEngine::padButtonPressed, pos);
                
            }else if(!gamepad.dpad.up.isPressed){

                changeState(U4DEngine::padDPadUpButton, U4DEngine::padButtonReleased, pos);
            }

            if (gamepad.dpad.down.isPressed) {
                
                changeState(U4DEngine::padDPadDownButton, U4DEngine::padButtonPressed, pos);

            }else if(!gamepad.dpad.down.isPressed){

                changeState(U4DEngine::padDPadDownButton, U4DEngine::padButtonReleased, pos);

            }

            if (gamepad.dpad.left.isPressed) {
                
                changeState(U4DEngine::padDPadLeftButton, U4DEngine::padButtonPressed, pos);
                
            }else if(!gamepad.dpad.left.isPressed){

                changeState(U4DEngine::padDPadLeftButton, U4DEngine::padButtonReleased, pos);

            }

            if (gamepad.dpad.right.isPressed) {
                
                changeState(U4DEngine::padDPadRightButton, U4DEngine::padButtonPressed, pos);
                
            }else if(!gamepad.dpad.right.isPressed){

                changeState(U4DEngine::padDPadRightButton, U4DEngine::padButtonReleased, pos);
                
            }

        }
        
        //ANALOG STICKS
        // left stick
        if (gamepad.leftThumbstick == element) {

            U4DEngine::U4DVector2n padAxis(gamepad.leftThumbstick.xAxis.value,gamepad.leftThumbstick.yAxis.value);
            
            if (gamepad.leftThumbstick.up.isPressed || gamepad.leftThumbstick.down.isPressed || gamepad.leftThumbstick.left.isPressed || gamepad.leftThumbstick.right.isPressed) {
                
                changeState(U4DEngine::padLeftThumbstick, U4DEngine::padThumbstickMoved, padAxis);
                
            }else if(!gamepad.leftThumbstick.up.isPressed && !gamepad.leftThumbstick.down.isPressed && !gamepad.leftThumbstick.left.isPressed && !gamepad.leftThumbstick.right.isPressed){

                changeState(U4DEngine::padLeftThumbstick, U4DEngine::padThumbstickReleased, padAxis);
                
            }

        }

        // right stick
        if (gamepad.rightThumbstick == element) {

            U4DEngine::U4DVector2n padAxis(gamepad.rightThumbstick.xAxis.value,gamepad.rightThumbstick.yAxis.value);
            
            if (gamepad.rightThumbstick.up.isPressed || gamepad.rightThumbstick.down.isPressed || gamepad.rightThumbstick.left.isPressed || gamepad.rightThumbstick.right.isPressed) {
                
                changeState(U4DEngine::padRightThumbstick, U4DEngine::padThumbstickMoved, padAxis);
                
            }else if(!gamepad.rightThumbstick.up.isPressed && !gamepad.rightThumbstick.down.isPressed && !gamepad.rightThumbstick.left.isPressed && !gamepad.rightThumbstick.right.isPressed){

                changeState(U4DEngine::padRightThumbstick, U4DEngine::padThumbstickReleased, padAxis);
                
            }

        }
        
    } 
    
}
