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
#include "U11SpaceAnalyzer.h"
#include "U11PlayerDribbleState.h"
#include "U11PlayerInterceptState.h"
#include "U11PlayerStateInterface.h"
#include "U11Team.h"
#include "U11MessageDispatcher.h"
#include "U11Ball.h"

GameLogic::GameLogic():buttonHoldTime(0){
    
    scheduler=new U4DEngine::U4DCallback<GameLogic>;
    buttonHoldTimer=new U4DEngine::U4DTimer(scheduler);
    
}

GameLogic::~GameLogic(){
    
    delete scheduler;
    delete buttonHoldTimer;
}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    //get the closest player to the ball and change its state to chase the ball
    U11SpaceAnalyzer spaceAnalyzer;
    
    U11Player* player=spaceAnalyzer.getClosestPlayersToBall(team).at(0);
    team->setControllingPlayer(player);
    player->changeState(U11PlayerInterceptState::sharedInstance());
    
}

void GameLogic::setTeamToControl(U11Team *uTeam){
    
    team=uTeam;
    
}

void GameLogic::receiveTouchUpdate(void *uData){
    
    U11Player *player=team->getActivePlayer();
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
    if (player!=NULL) {
        
        TouchInputMessage touchInputMessage=*(TouchInputMessage*)uData;
        
        switch (touchInputMessage.touchInputType) {
            case actionButtonA:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
                    startButtonHoldTimer();
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    stopButtonHoldTimer();
                    
                    messageDispatcher->sendMessage(0.0, player, player, msgButtonAPressed,(void*)&buttonHoldTime);
                    
                }
            }
                
                break;
            case actionButtonB:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
                    startButtonHoldTimer();
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    stopButtonHoldTimer();
                    
                    messageDispatcher->sendMessage(0.0, player, player, msgButtonBPressed, (void*)&buttonHoldTime);
                    
                }
            }
                
                break;
                
            case actionJoystick:
                
            {
                if (touchInputMessage.touchInputData==joystickActive) {
                    
                    JoystickMessageData joystickMessageData;
                    
                    joystickMessageData.direction=touchInputMessage.joystickDirection;
                    
                    joystickMessageData.changedDirection=touchInputMessage.joystickChangeDirection;
                    
                    messageDispatcher->sendMessage(0.0, player, player, msgJoystickActive, (void*)&joystickMessageData);
                    
                }else if(touchInputMessage.touchInputData==joystickInactive){
                    
                    messageDispatcher->sendMessage(0.0, player, player, msgJoystickNotActive);
                    
                }
            }
                
                break;
                
            default:
                break;
        }
        
    }
    
}

void GameLogic::increaseButtonHoldTime(){
    
    buttonHoldTime++;
    
    
}

void GameLogic::startButtonHoldTimer(){
    
    buttonHoldTime=4;
    
    scheduler->scheduleClassWithMethodAndDelay(this, &GameLogic::increaseButtonHoldTime, buttonHoldTimer,0.1, true);
    
}

void GameLogic::stopButtonHoldTimer(){
    
    scheduler->unScheduleTimer(buttonHoldTimer);
    
    if (buttonHoldTime>10) {
        
        buttonHoldTime=10;
        
    }
    
    //multiply the speed by 10
    buttonHoldTime*=2;
    
}
