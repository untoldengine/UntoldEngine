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
    
//    //set my main actor and attach camera to follow it
//    robot=dynamic_cast<MyCharacter*>(searchChild("robot"));
    
//    buttonA=getGameController()->getButtonWithName("buttonA");
//    buttonB=getGameController()->getButtonWithName("buttonB");
//    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){


    
//    if (buttonA->getIsPressed()) {
//        
//        robot->changeState(kWalking);
//        
//    }else if(buttonA->getIsReleased()){
//        
//        robot->changeState(kNull);
//    }
//    
//    if (buttonB->getIsPressed()) {
//        
//        robot->changeState(kJump);
//        
//        
//    }else if(buttonB->getIsReleased()){
//        
//        robot->changeState(kNull);
//        
//    }
//    
//    if(joystick->getIsActive()){
//        
//        //robot->changeState(kRotating);
//        U4DEngine::U4DVector3n joyData=joystick->getDataPosition();
//        //robot->setJoystickData(joyData);
//        
//        U4DEngine::U4DVector3n setView(joyData.x*10.0,robot->getAbsolutePosition().y,-joyData.y*10.0);
//        
//        robot->viewInDirection(setView);
//        
//    }
    
}



