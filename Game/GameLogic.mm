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

//#include "U11AISystem.h"
//#include "U11AIRecoverState.h"
//#include "U11AIDefenseState.h"
//#include "U11AIAttackState.h"
//#include "U11AIStateManager.h"

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
    
    buttonA=getGameController()->getButtonWithName("buttonA");
    buttonB=getGameController()->getButtonWithName("buttonB");
    joystick=getGameController()->getJoyStickWithName("joystick");
    
    //get the closest player to the ball and change its state to chase the ball
    U11SpaceAnalyzer spaceAnalyzer;
    
    U11Player* player=spaceAnalyzer.analyzeClosestPlayersToBall(team->getOppositeTeam()).at(0);
    //team->setControllingPlayer(player);
    player->changeState(U11PlayerInterceptState::sharedInstance());
    
}

void GameLogic::setTeamToControl(U11Team *uTeam){
    
    team=uTeam;
    
}

void GameLogic::receiveTouchUpdate(){
    
    U11Player *player=team->getActivePlayer();
    
    U11MessageDispatcher *messageDispatcher=U11MessageDispatcher::sharedInstance();
    
//    if (team->getAISystem()->getStateManager()->getCurrentState()==U11AIRecoverState::sharedInstance()) {
//        
//        std::cout<<"In recover state"<<std::endl;
//    }else if (team->getAISystem()->getStateManager()->getCurrentState()==U11AIDefenseState::sharedInstance()) {
//        
//        std::cout<<"In defense state"<<std::endl;
//    }else if (team->getAISystem()->getStateManager()->getCurrentState()==U11AIAttackState::sharedInstance()) {
//        
//        std::cout<<"In attacking state"<<std::endl;
//    }
    
    if (player!=NULL) {
        
        if (buttonA->getIsPressed()) {
            
            startButtonHoldTimer();
            
            
        }else if(buttonA->getIsReleased()){
            
            stopButtonHoldTimer();
            
            messageDispatcher->sendMessage(0.0, player, player, msgButtonAPressed,(void*)&buttonHoldTime);
            
        }
        
        if (buttonB->getIsPressed()) {
            
            startButtonHoldTimer();
            
        }else if(buttonB->getIsReleased()){
            
            stopButtonHoldTimer();
            
            messageDispatcher->sendMessage(0.0, player, player, msgButtonBPressed, (void*)&buttonHoldTime);
        }
        
        if(joystick->getIsActive()){
            
            U4DEngine::U4DVector3n joystickDirection=joystick->getDataPosition();
            
            joystickDirection.z=-joystickDirection.y;
        
            joystickDirection.y=0;
            
            joystickDirection.normalize();
            
            JoystickMessageData joystickMessageData;
            
            joystickMessageData.direction=joystickDirection;
            
            if (joystick->getDirectionReversal()) {
                
                joystickMessageData.changedDirection=true;
                
            }else{
                
                joystickMessageData.changedDirection=false;
                
            }
            
            messageDispatcher->sendMessage(0.0, player, player, msgJoystickActive, (void*)&joystickMessageData);
            
            
        }else{
            
            messageDispatcher->sendMessage(0.0, player, player, msgJoystickNotActive);
            
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
    buttonHoldTime*=10;
    
}
