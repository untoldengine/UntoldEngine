//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"
#include "U4DControllerInterface.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"

#include "U4DLights.h"

GameLogic::GameLogic(){

    
}

GameLogic::~GameLogic(){


}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
    
}

void GameLogic::setMainPlayer(SoccerPlayer *uPlayer){
    
    player=uPlayer;
    
}


void GameLogic::receiveTouchUpdate(){
    
    if (buttonA->getIsPressed()) {
        
        //player->translateBy(1.0, 0.0, 0.0);
        
        std::cout<<"button A is pressed"<<std::endl;
        
    }else if(buttonA->getIsReleased()){
        
        std::cout<<"button A is released"<<std::endl;
        
    }
    
    if (buttonB->getIsPressed()) {
        
        //player->translateBy(-1.0, 0.0, 0.0);
        
        std::cout<<"button B is pressed"<<std::endl;
        
    }else if(buttonB->getIsReleased()){
        
       std::cout<<"button B is released"<<std::endl;
    }
    
    if(joystick->getIsActive()){
        /*
        U4DEngine::U4DVector3n joystickDirection=joystick->getDataPosition();
        
        joystickDirection.z=-joystickDirection.y;
        
        joystickDirection.y=0;
        
        joystickDirection.normalize();
        */
        
        
    }else{
        
        
    }
    
}

