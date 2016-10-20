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
#include "U4DControllerInterface.h"
#include "GameController.h"

void GameLogic::update(double dt){

    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    ninja=dynamic_cast<MyCharacter*>(searchChild("ninja"));
}

void GameLogic::receiveTouchUpdate(){

    std::cout<<"Recieved touch"<<std::endl;
}

void GameLogic::controllerAction(void* uControllerAction){
    
    ControllerSource source=*static_cast<ControllerSource*>(uControllerAction);
    
    U4DEngine::U4DVector3n joystickData=getGameController()->getJoyStickData("myJoystick");
    
    switch (source) {
        case joystick:
        
            gameEntityState=kRotating;
            
            ninja->setJoystickData(joystickData);
            ninja->changeState(&gameEntityState);
            
            break;
            
        case buttonA:
            
            gameEntityState=kWalking;
            ninja->changeState(&gameEntityState);
            
            break;
            
        case buttonB:

            gameEntityState=kJumping;
            ninja->changeState(&gameEntityState);
            break;
            
        default:
            break;
    }
    
}

