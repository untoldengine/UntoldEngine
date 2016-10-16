//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"
#include "MyCharacter.h"
#include "UserCommonProtocols.h"

void GameLogic::update(double dt){

    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    ninja=dynamic_cast<MyCharacter*>(searchChild("ninja"));
}


void GameLogic::controllerAction(void* uControllerAction){
    
    ControllerSource source=*static_cast<ControllerSource*>(uControllerAction);
    
    switch (source) {
        case joystick:
            std::cout<<"Input from joystick"<<std::endl;
            
            gameEntityState=kRotating;
            ninja->changeState(&gameEntityState);
            
            break;
            
        case buttonA:
            std::cout<<"Input from Button A"<<std::endl;
           
            gameEntityState=kWalking;
            ninja->changeState(&gameEntityState);
            
            break;
            
        case buttonB:
            std::cout<<"Input from Button B"<<std::endl;
           
            gameEntityState=kJumping;
            ninja->changeState(&gameEntityState);
            break;
            
        default:
            break;
    }
    
}

