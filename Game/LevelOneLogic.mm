//
//  LevelOneLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "LevelOneLogic.h"
#include "LevelOneWorld.h"
#include "U4DDirector.h"
#include "CommonProtocols.h"
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

LevelOneLogic::LevelOneLogic():stickActive(false),stickDirection(0.0,0.0,0.0),controllingTeam(nullptr),currentMousePosition(0.5,0.5),showDirectionLine(false){
    
}

LevelOneLogic::~LevelOneLogic(){
    
}

void LevelOneLogic::update(double dt){
    
//    pPlayer=controllingTeam->getControllingPlayer();
//    controllingTeam->computeFormationPosition();
//
//
//    if (showDirectionLine==true && pPlayer!=nullptr) {
//
//        U4DEngine::U4DVector3n playerDir=pPlayer->getViewInDirection();
//
//        U4DEngine::U4DVector4n params0(playerDir.x,playerDir.y,playerDir.z,0.0);
//
//        //send data to player indicator
//        //pPlayerIndicator->updateShaderParameterContainer(0, params0);
//
//
//        U4DEngine::U4DVector3n activePlayerPosition=pPlayer->getAbsolutePosition();
//
//        U4DEngine::U4DVector4n params(activePlayerPosition.x/100.0,activePlayerPosition.z/67.0,currentMousePosition.x,currentMousePosition.y);
//        pGround->updateShaderParameterContainer(0.0, params);
//
//    }
    
}

void LevelOneLogic::init(){
    
    //1. Get a pointer to the LevelOneWorld object
    LevelOneWorld *pEarth=dynamic_cast<LevelOneWorld*>(getGameWorld());
    
    //2. Search for the player object
    pPlayer=dynamic_cast<Player*>(pEarth->searchChild("player0"));
    
    //3. Get the field object
    pGround=dynamic_cast<U4DEngine::U4DGameObject*>(pEarth->searchChild("field"));
    
    //get instance of director
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    //get device type
    if(director->getDeviceOSType()==U4DEngine::deviceOSMACX){
        
        if(!director->getGamePadControllerPresent()){
            
            //show lines if using keyboard support
            showDirectionLine=true;
        
        }
    }
}

void LevelOneLogic::setControllingTeam(Team *uTeam){
    
    controllingTeam=uTeam;
    
}

void LevelOneLogic::setPlayerIndicator(U4DEngine::U4DShaderEntity *uPlayerIndicator){
    
    pPlayerIndicator=uPlayerIndicator;
    
}

void LevelOneLogic::receiveUserInputUpdate(void *uData){
    
    U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
    
    if(controllingTeam!=nullptr){
        pPlayer=controllingTeam->getControllingPlayer();
    }
    
    
    if(pPlayer!=nullptr){
        
        switch (controllerInputMessage.inputElementType) {
            
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

                        pPlayer->setEnableHalt(true);
                        
                        if(pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()){
                            pPlayer->changeState(PlayerStateChase::sharedInstance());
                        }

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
                    
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                }
            }
                break;
                
            case U4DEngine::macKeyS:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    pPlayer->setEnablePassing(true);
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                    
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
                    
                    if(pPlayer->getCurrentState()!=PlayerStateTap::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance()){
                        
                        pPlayer->setMoveDirection(joystickDirection);
                    }
                   

                   pPlayer->setEnableDribbling(true);

                   pPlayer->setDribblingDirection(joystickDirection);
                   
                   
               }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                   
                   
                   pPlayer->setEnableHalt(true);
                   
                   if(pPlayer->getCurrentState()!=PlayerStateChase::sharedInstance()){
                       pPlayer->changeState(PlayerStateChase::sharedInstance());
                   }
                   
               }
            
            break;
                
            case U4DEngine::mouse:
            {
                
                if(controllerInputMessage.inputElementAction==U4DEngine::mouseActive){
                
                    //SNIPPET TO USE FOR MOUSE ABSOLUTE POSITION
                    currentMousePosition=controllerInputMessage.inputPosition;
                    
//                    U4DEngine::U4DVector3n mousedirection(controllerInputMessage.inputPosition.x,0.0,controllerInputMessage.inputPosition.y);
//
//                    if(pPlayer->getCurrentState()!=PlayerStateTap::sharedInstance() && pPlayer->getCurrentState()!=PlayerStateHalt::sharedInstance()){
//
//                         pPlayer->setMoveDirection(mousedirection);
//                     }
//
//
//                    pPlayer->setEnableDribbling(true);
//
//                    pPlayer->setDribblingDirection(mousedirection);

                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){
                    
                    
                }
                
            }
                
                break;
                
            default:
                break;
        }
    }
    
    
    
}
