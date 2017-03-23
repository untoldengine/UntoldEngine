//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"
#include "UserCommonProtocols.h"
#include "U4DControllerInterface.h"
#include "GameController.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "CommonProtocols.h"

#include "U11PlayerDribbleState.h"
#include "U11PlayerChaseBallState.h"
#include "U11PlayerStateInterface.h"
#include "U11Team.h"
#include "U11MessageDispatcher.h"

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
    //get the closest player to the ball and change its state to chase the ball
    U11Player* player=team->analyzeClosestPlayersToBall().at(0);
    
    player->changeState(U11PlayerChaseBallState::sharedInstance());
    
}

void GameLogic::setTeamToControl(U11Team *uTeam){
    
    team=uTeam;
    
}

void GameLogic::receiveTouchUpdate(){
    
    bool joystickActive=false;
    
    U11Player *player=team->getControllingPlayer();
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    if (player!=NULL) {
        
        if (buttonA->getIsPressed()) {
            
            messageDispatcher->sendMessage(0.0, player, player, msgButtonAPressed);
            
        }else if(buttonA->getIsReleased()){
            
            
            
        }
        
        if (buttonB->getIsPressed()) {
            
            messageDispatcher->sendMessage(0.0, player, player, msgButtonBPressed);
            
        }else if(buttonB->getIsReleased()){
            
            
        }
        
        if(joystick->getIsActive()){
            
            U4DEngine::U4DVector3n joystickDirection=joystick->getDataPosition();
            
            joystickDirection.normalize();
            
            player->setJoystickDirection(joystickDirection);
            
            joystickActive=true;
            
            player->setDirectionReversal(joystick->getDirectionReversal());
            
            player->setJoystickActive(true);
            
        }else{
            
            player->setJoystickActive(false);
        
        }
        
    }
    
}
