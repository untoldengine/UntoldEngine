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
#include "U11Ball.h"

GameLogic::GameLogic():ballKickSpeed(0){

    scheduler=new U4DEngine::U4DCallback<GameLogic>;
    ballKickSpeedTimer=new U4DEngine::U4DTimer(scheduler);
    
}

GameLogic::~GameLogic(){

}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
    //get the ball
    soccerBall=team->getSoccerBall();
    
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
            
            startBallKickSpeedTimer();
            
            
        }else if(buttonA->getIsReleased()){
            
            stopBallKickSpeedTimer();
            
            player->setBallKickSpeed(ballKickSpeed);
            
            messageDispatcher->sendMessage(0.0, player, player, msgButtonAPressed);
            
        }
        
        if (buttonB->getIsPressed()) {
            
            startBallKickSpeedTimer();
            
        }else if(buttonB->getIsReleased()){
            
            stopBallKickSpeedTimer();
            
            player->setBallKickSpeed(ballKickSpeed);
            
            messageDispatcher->sendMessage(0.0, player, player, msgButtonBPressed);
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

void GameLogic::increaseBallKickSpeed(){
    
    ballKickSpeed++;
    
 
}

void GameLogic::startBallKickSpeedTimer(){
    
    ballKickSpeed=4;
    
    scheduler->scheduleClassWithMethodAndDelay(this, &GameLogic::increaseBallKickSpeed, ballKickSpeedTimer,0.1, true);
    
}

void GameLogic::stopBallKickSpeedTimer(){
    
    scheduler->unScheduleTimer(ballKickSpeedTimer);
    
    if (ballKickSpeed>10) {
        
        ballKickSpeed=10;
        
    }
    
    //multiply the speed by 10
    ballKickSpeed*=10;
    
}
