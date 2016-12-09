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
#include "Flank.h"
#include "FlankGun.h"
#include "U4DCamera.h"

void GameLogic::update(double dt){

    
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    
    U4DEngine::U4DVector3n cameraAimVector=flank->getAimVector();
    
    camera->viewInDirection(cameraAimVector);
    
    
}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    tank=dynamic_cast<Tank*>(searchChild("tankbody"));
    
    flank=dynamic_cast<Flank*>(searchChild("flankbase"));
        
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){
    
    if (buttonA->getIsPressed()) {
        
        U4DEngine::U4DWorld *world=getGameWorld();
        
        Bullet *bullet=new Bullet();
        
        bullet->init("bullet", "characterscript.u4d");
        
        bullet->translateTo(flank->getAbsolutePosition().x,flank->getAbsolutePosition().y,flank->getAbsolutePosition().z);
        
        U4DEngine::U4DVector3n viewDirection=flank->getAimVector();
        
        bullet->setEntityForwardVector(viewDirection);
       
        bullet->changeState(kShooting);
        
        world->addChild(bullet);
        
        bullet->loadRenderingInformation();
        
        bullet->setWorld(world);
        
        
    }else if(buttonA->getIsReleased()){
        
    }
    
    if (buttonB->getIsPressed()) {
        
        
    }else if(buttonB->getIsReleased()){
        
        
    }
    
    if(joystick->getIsActive()){
        
        U4DEngine::U4DVector3n joyData=joystick->getDataPosition();
        
        flank->changeState(kAiming);
        
        flank->setJoystickData(joyData);
    
    }
    
}



