//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"
#include "Tank.h"
#include "UserCommonProtocols.h"
#include "U4DControllerInterface.h"
#include "GameController.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "CommonProtocols.h"
#include "Bullet.h"
#include "U4DWorld.h"
#include "Tank.h"
#include "AntiAircraft.h"
#include "AntiAircraftGun.h"
#include "U4DCamera.h"

void GameLogic::update(double dt){

    
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    
    U4DEngine::U4DVector3n cameraAimVector=antiAircraft->getAimVector();
    cameraAimVector.y*=5.0;
    camera->viewInDirection(cameraAimVector);
    
    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    antiAircraft=dynamic_cast<AntiAircraft*>(searchChild("antiaircraftbase"));
        
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){
    
    if (buttonA->getIsPressed()) {
        
        antiAircraft->changeState(kShooting);
        
    }else if(buttonA->getIsReleased()){
        
    }
    
    if (buttonB->getIsPressed()) {
        
        
    }else if(buttonB->getIsReleased()){
        
        
    }
    
    if(joystick->getIsActive()){
        
        U4DEngine::U4DVector3n joyData=joystick->getDataPosition();
        
        antiAircraft->changeState(kAiming);
        
        antiAircraft->setJoystickData(joyData);
    
    }
    
}



