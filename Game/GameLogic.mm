//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "GameLogic.h"
#include "Earth.h"

using namespace U4DEngine;

GameLogic::GameLogic(){
    
    
}

GameLogic::~GameLogic(){
    
   
}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
}


void GameLogic::receiveUserInputUpdate(void *uData){
    
    //1. Get the user-input message from the structure
    
    ControllerInputMessage controllerInputMessage=*(ControllerInputMessage*)uData;
    
    //check the astronaut model exists
    if(pAstronaut!=nullptr){
        
        //2. Determine what was pressed, buttons, keys or joystick
        
        switch (controllerInputMessage.controllerInputType) {
                
                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case actionButtonA:
            {
                //4. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //4a. What action to take if button was pressed
                    std::cout<<"Button A Pressed"<<std::endl;
                    
                    //5. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
                
                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
            case actionButtonB:
            {
                //7. If button was pressed
                if (controllerInputMessage.controllerInputData==buttonPressed) {
                    
                    //7a. What action to take if button was pressed
                    std::cout<<"Button B Pressed"<<std::endl;
                    
                    //8. If button was released
                }else if(controllerInputMessage.controllerInputData==buttonReleased){
                    
                    
                }
                
            }
                
                break;
                
                //9. Did joystic on a mobile or game controller receive an action from the user. (Arrow keys and Mouse on Mac)
            case actionJoystick:
            {
                //10. Joystick was moved
                
                if (controllerInputMessage.controllerInputData==joystickActive) {
                    
                    //11. Get joystick movement
                    JoystickMessageData joystickMessageData;
                    
                    //11a. Get Joystick direction
                    joystickMessageData.direction=controllerInputMessage.joystickDirection;
                    
                    //12. What action to take when joystick is moved.
                    std::cout<<"Joystick moved"<<std::endl;
                    
                    
                }else if(controllerInputMessage.controllerInputData==joystickInactive){
                    
                    
                }
                
            }
                
                break;
                
            default:
                break;
        }
        
    }
    
}
