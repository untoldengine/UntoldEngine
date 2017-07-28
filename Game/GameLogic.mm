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


void GameLogic::receiveTouchUpdate(){
    
    if (buttonA->getIsPressed()) {
        
        player->playAnimation();
        
        
    }else if(buttonA->getIsReleased()){
        
        
    }
    
    if (buttonB->getIsPressed()) {
        
        
        
    }else if(buttonB->getIsReleased()){
        
       
    }
    
    if(joystick->getIsActive()){
        
        U4DEngine::U4DVector3n joystickDirection=joystick->getDataPosition();
        
        joystickDirection.z=-joystickDirection.y;
        
        joystickDirection.y=0;
        
        joystickDirection.normalize();
        
        
        
    }else{
        
        
    }
    
}

