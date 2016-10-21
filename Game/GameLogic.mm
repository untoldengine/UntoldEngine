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
#include "CommonProtocols.h"

void GameLogic::update(double dt){

    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    ninja=dynamic_cast<MyCharacter*>(searchChild("ninja"));
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
}

void GameLogic::receiveTouchUpdate(){

    
    if (buttonA->getIsPressed()) {
        
        std::cout<<"Pressed button A"<<std::endl;
        
    }else if(buttonA->getIsReleased()){
        
        std::cout<<"Released button A"<<std::endl;
        
    }
    
    if (buttonB->getIsPressed()) {
        
        std::cout<<"Pressed button B"<<std::endl;
        
    }else if(buttonB->getIsReleased()){
        
        std::cout<<"Released button B"<<std::endl;
        
    }
    
}



