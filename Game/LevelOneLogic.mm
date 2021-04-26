//
//  LevelOneLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include <stdio.h>
#include <iostream>
#include "LevelOneLogic.h"
#include "LevelOneWorld.h"
#include "U4DDirector.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "UserCommonProtocols.h"
#include "Ball.h"
#include "LevelOneWorld.h"
#include "Team.h"
#include "PlayerStateIdle.h"
#include "PlayerStateDribble.h"
#include "PlayerStateChase.h"
#include "PlayerStateHalt.h"
#include "PlayerStatePass.h"
#include "PlayerStateShoot.h"
#include "PlayerStateTap.h"
#include "PlayerStateGoHome.h"
#include "PlayerStateIntercept.h"
#include "U4DAABB.h"
#include "TeamStateGoingHome.h"
#include "TeamStateReady.h"
#include "MessageDispatcher.h"
#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "U4DText.h"
#include "U4DCameraInterface.h"
#include "U4DCameraBasicFollow.h"

LevelOneLogic::LevelOneLogic():stickActive(false),stickDirection(0.0,0.0,0.0),controllingTeam(nullptr),currentMousePosition(0.5,0.5),showDirectionLine(false),messagleLabelIsShown(false),goalCount(0),clockTime(30){
    
    //Create the callback. Notice that you need to provide the name of the class
    outOfBoundScheduler=new U4DEngine::U4DCallback<LevelOneLogic>;

    //create the timer
    outOfBoundTimer=new U4DEngine::U4DTimer(outOfBoundScheduler);
    
    //Create the callback. Notice that you need to provide the name of the class
    messageLabelScheduler=new U4DEngine::U4DCallback<LevelOneLogic>;

    //create the timer
    messageLabelTimer=new U4DEngine::U4DTimer(messageLabelScheduler);
    
    //Create the callback. Notice that you need to provide the name of the class
    timeUpScheduler=new U4DEngine::U4DCallback<LevelOneLogic>;

    //create the timer
    timeUpTimer=new U4DEngine::U4DTimer(timeUpScheduler);
    
}

LevelOneLogic::~LevelOneLogic(){
    
    //In the class destructor,  make sure to delete the U4DCallback and U4DTimer as follows.
    //Make sure that before deleting the scheduler and timer, to first unsubscribe the timer.

    outOfBoundScheduler->unScheduleTimer(outOfBoundTimer);
    messageLabelScheduler->unScheduleTimer(messageLabelTimer);
    timeUpScheduler->unScheduleTimer(timeUpTimer);
    
    delete outOfBoundScheduler;
    delete outOfBoundTimer;
    
    delete messageLabelScheduler;
    delete messageLabelTimer;
    
    delete timeUpScheduler;
    delete timeUpTimer;
    
}

void LevelOneLogic::computeVoronoi(){
//    //VORONOI START-Leaving this as an example
//    float high = 0.8, low = -0.8;
//
//
//    voronoiSegments.clear();
//
//    //fortune's algorithm
//    int sitesSize=6;
//
//    float xValues[sitesSize];
//    float yValues[sitesSize];
//
//
//    for(int i=0;i<markingTeam->getPlayers().size();i++){
//
//        U4DEngine::U4DVector3n pos=markingTeam->getPlayers().at(i)->getAbsolutePosition();
//
//        pos.x/=8.0;
//        pos.z/=14.0;
//
//        xValues[i]=pos.x;
//        yValues[i]=pos.z;
//
//    }
//
//    U4DEngine::U4DVector3n pos=pPlayer->getAbsolutePosition();
//    pos.x/=8.0;
//    pos.z/=14.0;
//    xValues[5]=pos.x;
//    yValues[5]=pos.z;
//
//
//    voronoiDiagram::VoronoiDiagramGenerator vdg;
//
//    vdg.generateVoronoi(xValues,yValues,sitesSize, -8.0,8.0,-14.0,14.0,0);
//
//    vdg.resetIterator();
//
//    float x1,y1,x2,y2;
//
//    while(vdg.getNext(x1,y1,x2,y2))
//    {
//
//        x1=clampVoronoi(x1, high, low);
//        y1=clampVoronoi(y1, high, low);
//        x2=clampVoronoi(x2, high, low);
//        y2=clampVoronoi(y2, high, low);
//        U4DEngine::U4DVector4n params(x1,y1,x2,y2);
//
//        voronoiSegments.push_back(params);
//
//    }
    
}

float LevelOneLogic::clampVoronoi(float x, float upper, float lower){ 
    return std::min(upper, std::max(x, lower));
}

void LevelOneLogic::update(double dt){
    
    pPlayer=controllingTeam->getControllingPlayer();
   
        
        markingTeam->update(dt);
        controllingTeam->update(dt);
        
        Ball *ball=Ball::sharedInstance();
        
        if (ball->getState()==scored) {
            
            goalCount++;
            
            std::string scoreString="1-";
            scoreString+=std::to_string(goalCount);
            
            score->setText(scoreString.c_str());
            
            showGoalLabel();
            
            MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
            messageDispatcher->sendMessage(0.0, controllingTeam, msgGoHome);
            messageDispatcher->sendMessage(0.0, markingTeam, msgGoHome);
            
           
            //send ball home
            U4DEngine::U4DVector3n ballHomePosition=ball->homePosition;
            ball->translateTo(ballHomePosition);
            ball->resumeCollisionBehavior();
            ball->setState(stopped);
            
        }
    
    if(pPlayer!=nullptr){
        
        U4DEngine::U4DVector3n pos=pPlayer->getAbsolutePosition();
        pos.x/=22.5;
        pos.z/=40.0;
        
        U4DEngine::U4DVector4n param0(pos.x,pos.z,0.0,0.0);
        pGround->updateShaderParameterContainer(0, param0);
        
        //comput the yaw of the hero soldier
        U4DEngine::U4DVector3n v0=pPlayer->getEntityForwardVector();
        U4DEngine::U4DMatrix3n m=pPlayer->getAbsoluteMatrixOrientation();
        U4DEngine::U4DVector2n heroPosition(pPlayer->getAbsolutePosition().x,pPlayer->getAbsolutePosition().z);
        U4DEngine::U4DVector3n xDir(1.0,0.0,0.0);
        U4DEngine::U4DVector3n upVector(0.0,1.0,0.0);

        U4DEngine::U4DVector3n v1=m*v0;

        float yaw=v0.angle(v1);

        v1.normalize();

        if (xDir.dot(v1)>U4DEngine::zeroEpsilon) {

            yaw=360.0-yaw;
        }

        //send the yaw information to the navigation shader
        U4DEngine::U4DVector4n paramAngle(yaw,0.0,0.0,0.0);
        pGround->updateShaderParameterContainer(1, paramAngle);
        
    }
    
    
    //show voronoi lines
//    U4DEngine::U4DVector4n param0(voronoiSegments.size(),0.0,0.0,0.0);
//    pGround->updateShaderParameterContainer(0.0, param0);
//
//    int count=1;
//
//    for(auto &n:voronoiSegments){
//
//        pGround->updateShaderParameterContainer(count, n);
//
//        count++;
//
//    }
    //end show voronoi lines
    
    //pPlayer=controllingTeam->getControllingPlayer();

//    controllingTeam->computeFormationPosition();
//    markingTeam->computeFormationPosition();

    if (showDirectionLine==true && pPlayer!=nullptr) {

        //U4DEngine::U4DVector3n playerDir=pPlayer->getViewInDirection();

        //U4DEngine::U4DVector4n params0(playerDir.x,playerDir.y,playerDir.z,0.0);

        //send data to player indicator
        //pPlayerIndicator->updateShaderParameterContainer(0, params0);


//        U4DEngine::U4DVector3n activePlayerPosition=pPlayer->getAbsolutePosition();
//
//        U4DEngine::U4DVector4n params(activePlayerPosition.x/100.0,activePlayerPosition.z/67.0,currentMousePosition.x,currentMousePosition.y);
//        pGround->updateShaderParameterContainer(0.0, params);

    }
    
}

void LevelOneLogic::timesUp(){
    
    clockTime--;
    
    std::string clockTimeString="00:";
    clockTimeString+=std::to_string(clockTime);
    
    gameClock->setText(clockTimeString.c_str());
    
    if (clockTime==0.0) {
        showGameOverLabel();
        
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
        messageDispatcher->sendMessage(0.0, controllingTeam, msgGoHome);
        messageDispatcher->sendMessage(0.0, markingTeam, msgGoHome);
        
        Ball *ball=Ball::sharedInstance();
        //send ball home
        U4DEngine::U4DVector3n ballHomePosition=ball->homePosition;
        ball->translateTo(ballHomePosition);
        ball->resumeCollisionBehavior();
        ball->setState(stopped);
        
        clockTime=30.0;
        goalCount=0;
        
    }
}

void LevelOneLogic::showGameOverLabel(){
    
    if (messagleLabelIsShown==true) {
        removeMessageLabel();
    }
    
    messagleLabelIsShown=true;
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();
    
    //create Layers
    U4DEngine::U4DLayer* gameOverLayer=new U4DEngine::U4DLayer("gameoverLayer");
    
    //3. Create a text object. Provide the name of the font.
    U4DEngine::U4DText *gameOverText=new U4DEngine::U4DText("dribblyFont");

    if (goalCount<=1) {
        gameOverText->setText("You Lost");
    }else{
        
        //4. set the text you want to display
        gameOverText->setText("You Won");
        
    }
    
    gameOverText->translateBy(-0.7, 0.0, 0.0);
    
    //6. Add the text to the scenegraph
    gameOverLayer->addChild(gameOverText);
    
    layerManager->addLayerToContainer(gameOverLayer);

    //push layer
    layerManager->pushLayer("gameoverLayer");
    
    messageLabelTimer->setPause(false);
}

void LevelOneLogic::showGoalLabel(){
    
    if (messagleLabelIsShown==true) {
        removeMessageLabel();
    }
    
    messagleLabelIsShown=true;
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();
    
    //create Layers
    U4DEngine::U4DLayer* scoreLayer=new U4DEngine::U4DLayer("scoredLayer");
    
    //3. Create a text object. Provide the name of the font.
    U4DEngine::U4DText *myText=new U4DEngine::U4DText("dribblyFont");

    //4. set the text you want to display
    myText->setText("Goal");

    myText->translateBy(-0.2, 0.5, 0.0);
    
    //6. Add the text to the scenegraph
    scoreLayer->addChild(myText);
    
    layerManager->addLayerToContainer(scoreLayer);

    //push layer
    layerManager->pushLayer("scoredLayer");
    
    messageLabelTimer->setPause(false);
    
}

void LevelOneLogic::showOutOfBoundLabel(){
    
    if (messagleLabelIsShown==true) {
        removeMessageLabel();
    }
    
    messagleLabelIsShown=true;
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();
    
    //create Layers
    U4DEngine::U4DLayer* outOfBoundLayer=new U4DEngine::U4DLayer("outOfBoundLayer");
    
    //3. Create a text object. Provide the name of the font.
    U4DEngine::U4DText *myText=new U4DEngine::U4DText("dribblyFont");

    //4. set the text you want to display
    myText->setText("Kick-in");

    myText->translateBy(-0.5, 0.0, 0.0);
    
    //6. Add the text to the scenegraph
    outOfBoundLayer->addChild(myText);
    
    layerManager->addLayerToContainer(outOfBoundLayer);

    //push layer
    layerManager->pushLayer("outOfBoundLayer");
    
    messageLabelTimer->setPause(false);
}

void LevelOneLogic::removeMessageLabel(){
    
    //create layer manager
    U4DEngine::U4DLayerManager *layerManager=U4DEngine::U4DLayerManager::sharedInstance();
    
    layerManager->popLayer();
    
    messageLabelTimer->setPause(true);
    
    messagleLabelIsShown=false;
    
}


void LevelOneLogic::init(){
    
    //1. Get a pointer to the LevelOneWorld object
    LevelOneWorld *pEarth=dynamic_cast<LevelOneWorld*>(getGameWorld());

    //2. Search for the player object
    pPlayer=dynamic_cast<Player*>(pEarth->searchChild("player0"));

    //3. Get the field object
    pGround=dynamic_cast<U4DEngine::U4DGameObject*>(pEarth->searchChild("field"));

    //3. Create a text object. Provide the name of the font.
    gameClock=new U4DEngine::U4DText("dribblySmallFont");
    
    std::string clockTimeString="00:";
    clockTimeString+=std::to_string(clockTime);
    
    gameClock->setText(clockTimeString.c_str());
    gameClock->translateTo(0.3, 0.8, 0.0);
    
    pEarth->addChild(gameClock,-20);
    
    
    score=new U4DEngine::U4DText("dribblySmallFont");
    std::string scoreString="1-";
    scoreString+=std::to_string(goalCount);
    
    score->setText(scoreString.c_str());
    
    score->translateTo(-0.7, 0.8, 0.0);
    
    pEarth->addChild(score,-20);
    
    //get instance of director
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    //get device type
    if(director->getDeviceOSType()==U4DEngine::deviceOSMACX){

        if(!director->getGamePadControllerPresent()){

            //show lines if using keyboard support
            showDirectionLine=true;

        }
    }
    
    controllingTeam->setControllingPlayer(pPlayer);
    outOfBoundScheduler->scheduleClassWithMethodAndDelay(this, &LevelOneLogic::outOfBound, outOfBoundTimer,1.0, true);
    
    messageLabelScheduler->scheduleClassWithMethodAndDelay(this, &LevelOneLogic::removeMessageLabel, messageLabelTimer,2.0, true);
    
    messageLabelTimer->setPause(true);

    timeUpScheduler->scheduleClassWithMethodAndDelay(this, &LevelOneLogic::timesUp, timeUpTimer,1.0, true);
}

void LevelOneLogic::outOfBound(){
    
    Ball *ball=Ball::sharedInstance();
    
    U4DEngine::U4DPoint3n ballPosition=ball->getAbsolutePosition().toPoint();
    
    //create a AABB box
    U4DEngine::U4DPoint3n fieldMinBound(-19.0,-2.0,-34.0);
    U4DEngine::U4DPoint3n fieldMaxBound(19.0,2.0,34.0);
    
    U4DEngine::U4DAABB fieldAABBBox(fieldMinBound,fieldMaxBound);
            
    //test if point is within the box
    if (!fieldAABBBox.isPointInsideAABB(ballPosition) && ball->getState()!=scored) {
        
        showOutOfBoundLabel();
        
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
        messageDispatcher->sendMessage(0.0, controllingTeam, msgGoHome);
        messageDispatcher->sendMessage(0.0, markingTeam, msgGoHome);

        ball->setState(stopped);
        //send ball home
        U4DEngine::U4DVector3n ballHomePosition=ball->homePosition;
        ball->translateTo(ballHomePosition);

    }
}

void LevelOneLogic::setControllingTeam(Team *uTeam){
    
    controllingTeam=uTeam;
    
}

void LevelOneLogic::setMarkingTeam(Team *uTeam){
    
    markingTeam=uTeam;
    
}

void LevelOneLogic::setPlayerIndicator(U4DEngine::U4DShaderEntity *uPlayerIndicator){
    
    pPlayerIndicator=uPlayerIndicator;
    
}

bool LevelOneLogic::teamsReady(){
    
    bool teamsAreReady=false;
    
    if(markingTeam->getCurrentState()!=TeamStateGoingHome::sharedInstance() && controllingTeam->getCurrentState()!=TeamStateGoingHome::sharedInstance()){
        
        
        MessageDispatcher *messageDispatcher=MessageDispatcher::sharedInstance();
        
        messageDispatcher->sendMessage(0.0, markingTeam, msgTeamStart);
        messageDispatcher->sendMessage(0.0, controllingTeam, msgTeamStart);
        
        teamsAreReady=true;
    }
    
    return teamsAreReady;
    
}

void LevelOneLogic::receiveUserInputUpdate(void *uData){
    
    U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
    
    if(controllingTeam!=nullptr){
        pPlayer=controllingTeam->getControllingPlayer();
    }
    
    
    
    if(pPlayer!=nullptr && teamsReady()){
        
        
        switch (controllerInputMessage.inputElementType) {
            
//            case U4DEngine::ioTouch:
//
//                if(controllerInputMessage.inputElementAction==U4DEngine::ioTouchesMoved){
//
//                    //Get the direction of the joystick
//                    U4DEngine::U4DVector2n digitalJoystickDirection=controllerInputMessage.inputPosition;
//
//                    U4DEngine::U4DVector3n joystickDirection3d(digitalJoystickDirection.x,0.0,digitalJoystickDirection.y);
//
//
//                    if(pPlayer->getCurrentState()!=PlayerStateTap::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance()){
//
//                         pPlayer->setMoveDirection(joystickDirection3d);
//                     }
//
//
//                    pPlayer->setEnableDribbling(true);
//
//                    pPlayer->setDribblingDirection(joystickDirection3d);
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::ioTouchesEnded){
//
//                    //pPlayer->setEnablePassing(true);
////                    pPlayer->setEnableHalt(true);
////
////                    if(pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()){
////                        pPlayer->changeState(PlayerStateChase::sharedInstance());
////                    }
//                }
//
//                break;
                
            case U4DEngine::uiJoystick:
            {
                
                if (controllerInputMessage.elementUIName.compare("joystick")==0 ) {
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickMoved){

                        //Get the direction of the joystick
                        U4DEngine::U4DVector2n digitalJoystickDirection=controllerInputMessage.joystickDirection;
                        
                        U4DEngine::U4DVector3n joystickDirection3d(digitalJoystickDirection.x,0.0,digitalJoystickDirection.y);

                        if(pPlayer->getCurrentState()!=PlayerStateTap::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance()){
                             
                             pPlayer->setMoveDirection(joystickDirection3d);
                         }
                        

                        pPlayer->setEnableDribbling(true);

                        pPlayer->setDribblingDirection(joystickDirection3d);
                    
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickReleased){
                            
                        //pPlayer->setEnablePassing(true);
                        //pPlayer->setEnableHalt(true);
                        pPlayer->setEnableShooting(true);
//
//                        if(pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()){
//                            pPlayer->changeState(PlayerStateChase::sharedInstance());
//                        }

                    }
                    
                }
                

            }
                break;
                
            case U4DEngine::uiButton:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiButtonPressed){
                    
                    //pass
                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
                        
                        pPlayer->setEnablePassing(true);
                    
                    //shoot
                    }else if (controllerInputMessage.elementUIName.compare("buttonB")==0){
                        
                        pPlayer->setEnableShooting(true);
                        
                    }
                    
                }else if (controllerInputMessage.inputElementAction==U4DEngine::uiButtonReleased){
                
                    
                
                }
                
                break;
            case U4DEngine::mouseLeftButton:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::mouseButtonPressed) {
                    
                    
                        
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseButtonReleased){
                    
                    
                    
                }
            }
                
                break;

                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
            case U4DEngine::macKeyA:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                    
                }
            }
                
                break;
                
                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
            case U4DEngine::macKeyD:
            {
                //7. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    
                    
                    //8. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    

                }
                
            }
                
                break;
                
            case U4DEngine::macKeyW:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    pPlayer->setEnableShooting(true);
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                }
            }
                break;
                
            case U4DEngine::macKeyS:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    pPlayer->setEnablePassing(true);
                    
                }
                
            }
                break;
                
                
            case U4DEngine::macShiftKey:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    pPlayer->setEnableDribbling(true);

                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    pPlayer->setEnableHalt(true);
                    
                    if(pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()){
                        pPlayer->changeState(PlayerStateChase::sharedInstance());
                    }
                }
                
            }
                break;
                
            case U4DEngine::padButtonA:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    std::cout<<"Started to pass"<<std::endl;
                    pPlayer->setEnablePassing(true);
                    
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padButtonB:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    pPlayer->setEnableShooting(true);
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padRightTrigger:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padLeftTrigger:
            
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                    
                }
            
            break;
                
            case U4DEngine::padLeftThumbstick:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
                                   
                   //Get joystick direction
                   U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,0.0,controllerInputMessage.joystickDirection.y);
                   
                    stickDirection=joystickDirection;
                    
                    if(pPlayer->getCurrentState()!=PlayerStateTap::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance() && pPlayer->getCurrentState()!=PlayerStatePass::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()&& pPlayer->getCurrentState()!=PlayerStateIntercept::sharedInstance()){

                         pPlayer->setMoveDirection(joystickDirection);
                     }

                    if (pPlayer->getCurrentState()!=PlayerStatePass::sharedInstance()) {
                        pPlayer->setEnableDribbling(true);

                        pPlayer->setDribblingDirection(joystickDirection);
                    }
                   
                   
               }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                   
                   
                   pPlayer->setEnableHalt(true);
//
//                   if(pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance()){
//                       pPlayer->changeState(PlayerStateHalt::sharedInstance());
//                   }
                   
               }
            
            break;
                
            case U4DEngine::mouse:
            {
                
                if(controllerInputMessage.inputElementAction==U4DEngine::mouseActive){
                
                    //SNIPPET TO USE FOR MOUSE ABSOLUTE POSITION
                    currentMousePosition=controllerInputMessage.inputPosition;
                    
                    U4DEngine::U4DVector3n mousedirection(controllerInputMessage.inputPosition.x,0.0,controllerInputMessage.inputPosition.y);

                    if(pPlayer->getCurrentState()!=PlayerStateTap::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance() && pPlayer->getCurrentState()!=PlayerStatePass::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()&& pPlayer->getCurrentState()!=PlayerStateIntercept::sharedInstance()){

                         pPlayer->setMoveDirection(mousedirection);
                     }

                    if (pPlayer->getCurrentState()!=PlayerStatePass::sharedInstance()) {
                        pPlayer->setEnableDribbling(true);

                        pPlayer->setDribblingDirection(mousedirection);
                    }
                    

                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){
                    
                    
                }
                
            }
                
                break;
                
            default:
                break;
        }
    }
    
    
}
