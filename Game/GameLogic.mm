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
#include "TankHead.h"

void GameLogic::update(double dt){

}

void GameLogic::init(){
    
    //set my main actor and attach camera to follow it
    tankBody=dynamic_cast<Tank*>(searchChild("tankbody"));
        
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
}

void GameLogic::receiveTouchUpdate(){

    TankHead * tankHead=tankBody->getTankHead();
    
    if (buttonA->getIsPressed()) {
        
        U4DEngine::U4DWorld *world=getGameWorld();
        
        Bullet *bullet=new Bullet();
        
        bullet->init("bullet", "characterscript.u4d");
        
        bullet->translateTo(tankHead->getAbsolutePosition().x,tankHead->getAbsolutePosition().y,tankHead->getAbsolutePosition().z);
        
        U4DEngine::U4DVector3n viewDirection(tankHead->getViewInDirection().x,tankHead->getAbsolutePosition().y,tankHead->getViewInDirection().z);
        
        bullet->setEntityForwardVector(viewDirection);
       
        bullet->changeState(kShooting);
        
        world->addChild(bullet);
        
        bullet->loadRenderingInformation();
        
        //robot->changeState(kWalking);
        
    }else if(buttonA->getIsReleased()){
        
        //robot->changeState(kNull);
    }
    
    if (buttonB->getIsPressed()) {
        
        //robot->changeState(kJump);
        
        
    }else if(buttonB->getIsReleased()){
        
        //robot->changeState(kNull);
        
    }
    
    if(joystick->getIsActive()){
        
        tankHead->changeState(kRotating);
        U4DEngine::U4DVector3n joyData=joystick->getDataPosition();
        tankHead->setJoystickData(joyData);
       
    }
    
}



