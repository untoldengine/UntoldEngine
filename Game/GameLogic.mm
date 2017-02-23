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
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "CommonProtocols.h"

#include "SoccerPlayerDribbleState.h"
#include "SoccerPlayerChaseBallState.h"
#include "SoccerPlayerStateInterface.h"

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    ball=dynamic_cast<SoccerBall*>(searchChild("ball"));
    field=dynamic_cast<SoccerField*>(searchChild("field"));
    player=dynamic_cast<SoccerPlayer*>(searchChild("pele"));
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){
    
    bool buttonAPressed=false;
    bool buttonBPressed=false;
    bool joystickActive=false;
    
    if (buttonA->getIsPressed()) {
        
        buttonAPressed=true;
        
    }else if(buttonA->getIsReleased()){
        
        
        
    }
    
    if (buttonB->getIsPressed()) {
        
        buttonBPressed=true;
        
        
    }else if(buttonB->getIsReleased()){
        
        
        
    }
    
    if(joystick->getIsActive()){
        
        U4DEngine::U4DVector3n joystickDirection=joystick->getDataPosition();
        
        joystickDirection.normalize();
    
        player->setJoystickDirection(joystickDirection);
        
        joystickActive=true;
    }
    
    
    player->receiveTouchUpdate(buttonAPressed, buttonBPressed, joystickActive);
    
}
