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
        
    }else if(buttonA->getIsReleased()){
        
        
    }
    
    if (buttonB->getIsPressed()) {
        
        //player->translateBy(-1.0, 0.0, 0.0);
        
    }else if(buttonB->getIsReleased()){
        
       
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

