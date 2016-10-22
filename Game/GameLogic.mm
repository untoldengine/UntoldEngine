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
    ninja=dynamic_cast<MyCharacter*>(searchChild("ninja"));
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){

    
    if (buttonA->getIsPressed()) {
        
        ninja->changeState(kWalking);
        
    }else if(buttonA->getIsReleased()){
        
        ninja->changeState(kNull);
    }
    
    if (buttonB->getIsPressed()) {
        
        ninja->changeState(kBow);
        
        
    }else if(buttonB->getIsReleased()){
        
        ninja->changeState(kNull);
        
    }
    
    if(joystick->getIsActive()){
        
       
    }
    
}



