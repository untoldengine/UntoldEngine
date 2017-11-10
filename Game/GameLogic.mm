//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"

#include "U4DControllerInterface.h"
#include "GameController.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "CommonProtocols.h"
#include "U4DCamera.h"
#include "U4DParticleSystem.h"
#include "Earth.h"
#include "MessageDispatcher.h"

GameLogic::GameLogic():points(0){
    
    guardian=nullptr;
    
}

GameLogic::~GameLogic(){
    
   
}

void GameLogic::update(double dt){
    
    if (guardian->guardianAte()) {
        
        increasePoints();
        guardian->resetAteCoin();
    }
}

void GameLogic::init(){
    
    
}

void GameLogic::setGuardian(GuardianModel *uGuardian){
    guardian=uGuardian;
}

void GameLogic::setText(U4DEngine::U4DText *uText){
    text=uText;
}

void GameLogic::increasePoints(){
    
    points++;
    
    std::string name="Points: ";
    
    name+=std::to_string(points);
    
    text->setText(name.c_str());
    
}

void GameLogic::receiveTouchUpdate(void *uData){
    
    MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();

    TouchInputMessage touchInputMessage=*(TouchInputMessage*)uData;

    if (guardian!=nullptr) {
        
        switch (touchInputMessage.touchInputType) {
            case actionButtonA:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
                    
                    std::cout<<"pressed"<<std::endl;
                    
                    
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
            case actionButtonB:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
                    
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
                
            case actionJoystick:
                
            {
                if (touchInputMessage.touchInputData==joystickActive) {
                    
                    JoystickMessageData joystickMessageData;
                    
                    joystickMessageData.direction=touchInputMessage.joystickDirection;
                    
                    joystickMessageData.changedDirection=touchInputMessage.joystickChangeDirection;
                    
                    
                    guardian->setPlayerHeading(joystickMessageData.direction);
                    
                    messageDispatcher->sendMessage(0.0, guardian, guardian, msgJoystickActive, (void*)&joystickMessageData);
                    
                    
                }else if(touchInputMessage.touchInputData==joystickInactive){
                    
                    messageDispatcher->sendMessage(0.0, guardian, guardian, msgJoystickNotActive);                }
            }
                
                break;
                
            default:
                break;
        }
        
    }
    
}


