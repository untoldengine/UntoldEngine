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

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    ball=dynamic_cast<SoccerBall*>(searchChild("ball"));
    field=dynamic_cast<SoccerField*>(searchChild("field"));
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){
    
    if (buttonA->getIsPressed()) {
        
        ball->setState(kGroundPass);
        
        
    }else if(buttonA->getIsReleased()){
        
        //ball->setState(kNull);
        
    }
    
    if (buttonB->getIsPressed()) {
        
        ball->setState(kAirPass);
        
        
    }else if(buttonB->getIsReleased()){
        
        //ball->setState(kNull);
        
    }
    
    if(joystick->getIsActive()){
        
        U4DEngine::U4DVector3n joyData=joystick->getDataPosition();
        joyPosition=joyData;
        
        joyPosition.normalize();
        
        ball->setJoystickData(joyPosition);
        
        //U4DEngine::U4DVector3n setView(joyPosition.x*10.0,ball->getAbsolutePosition().y,-joyPosition.y*10.0);
        
        //ball->viewInDirection(setView);
        //ball->setState(kNull);
    }
    
}
