//
//  SandboxLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxLogic.h"
#import <TargetConditionals.h>
#include "U4DDirector.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "SandboxWorld.h"
#include "U4DGameConfigs.h"
#include "U4DScriptManager.h"
#include "U4DCamera.h"

#include "U4DAnimationManager.h"


#include "U4DSceneManager.h"
#include "U4DScene.h"
#include "U4DSceneStateManager.h"
#include "U4DSceneEditingState.h"
#include "U4DScenePlayState.h"



#include "U4DClientManager.h"
#include "U4DLayerManager.h"
#include "U4DLayer.h"
#include "U4DDebugger.h"
#include "U4DCameraInterface.h"
#include "U4DCameraBasicFollow.h"

#include "U4DScriptManager.h"

SandboxLogic::SandboxLogic():pPlayer(nullptr){
    
}

SandboxLogic::~SandboxLogic(){
    
}

void SandboxLogic::update(double dt){
    
    
}

void SandboxLogic::init(){
    
    //1. Get a pointer to the LevelOneWorld object
//    SandboxWorld* pEarth=dynamic_cast<SandboxWorld*>(getGameWorld());
//    pPlayer=dynamic_cast<U4DEngine::U4DModel*>(pEarth->searchChild("player0.0"));
}



void SandboxLogic::receiveUserInputUpdate(void *uData){
    
    U4DEngine::U4DScriptManager *scriptManager=U4DEngine::U4DScriptManager::sharedInstance();
    scriptManager->userInputClosure(uData);
//    U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
//
//
//    if (pPlayer!=nullptr) {
//
//        switch (controllerInputMessage.inputElementType) {
//
//            case U4DEngine::uiButton:
//
//                if(controllerInputMessage.inputElementAction==U4DEngine::uiButtonPressed){
//
//
//                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
//
//                        //std::cout<<"Button A pressed"<<std::endl;
//
//
//                    }
//
//                }else if (controllerInputMessage.inputElementAction==U4DEngine::uiButtonReleased){
//
//                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
//
//
//
//                    }else if(controllerInputMessage.elementUIName.compare("buttonB")==0){
//
//
//
//
//                    }
//
//                }
//
//                break;
//
//            case U4DEngine::uiSlider:
//
//                if(controllerInputMessage.inputElementAction==U4DEngine::uiSliderMoved){
//
//
//                    if (controllerInputMessage.elementUIName.compare("sliderA")==0) {
//
//
//
//                    }else if(controllerInputMessage.elementUIName.compare("sliderB")==0){
//
//
//
//                    }
//
//                }
//
//                break;
//
//            case U4DEngine::uiJoystick:
//
//            if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickMoved){
//
//
//                if (controllerInputMessage.elementUIName.compare("joystick")==0) {
//
//                    //Get the direction of the joystick
//                    U4DEngine::U4DVector2n digitalJoystickDirection=controllerInputMessage.joystickDirection;
//
//                    U4DEngine::U4DVector3n joystickDirection3d(digitalJoystickDirection.x,0.0,digitalJoystickDirection.y);
//
//
//
//                }
//
//            }else if (controllerInputMessage.inputElementAction==U4DEngine::uiJoystickReleased){
//
//                if (controllerInputMessage.elementUIName.compare("joystick")==0) {
//
//
//
//                }
//
//            }
//
//            break;
//
//            case U4DEngine::uiCheckbox:
//
//                if(controllerInputMessage.inputElementAction==U4DEngine::uiCheckboxPressed){
//
//
//                    if (controllerInputMessage.elementUIName.compare("checkboxA")==0) {
//
//
//
//                    }else if(controllerInputMessage.elementUIName.compare("checkboxB")==0){
//
//
//                    }
//
//                }
//
//                break;
//
//            case U4DEngine::mouseLeftButton:
//            {
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::mouseLeftButtonPressed) {
//
//                    //std::cout<<"left clicked"<<std::endl;
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseLeftButtonReleased){
//
//
//                }
//            }
//
//                break;
//
//            case U4DEngine::mouseRightButton:
//            {
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::mouseRightButtonPressed) {
//
//                    //std::cout<<"left clicked"<<std::endl;
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseRightButtonReleased){
//
//
//                }
//            }
//
//                break;
//
//            case U4DEngine::macArrowKey:
//
//            {
//
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macArrowKeyActive) {
//
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macArrowKeyActive){
//
//
//                }
//            }
//
//                break;
//
//                //3. Did Button A on a mobile or game controller receive an action from the user (Key A on a Mac)
//            case U4DEngine::macKeyA:
//            {
//
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
//
//
//                }
//            }
//
//                break;
//
//                //6. Did Button B on a mobile or game controller receive an action from the user. (Key D on Mac)
//            case U4DEngine::macKeyD:
//            {
//                //7. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//
//                    //8. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
//
//                }
//
//            }
//
//                break;
//
//            case U4DEngine::macKeyW:
//            {
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
//
//
//                }
//            }
//                break;
//
//            case U4DEngine::macKeyS:
//            {
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyActive){
//
//
//                }
//
//            }
//                break;
//
//#if TARGET_OS_MAC && !TARGET_OS_IPHONE
//            //both keys P and U are used to set the scene into a Play or Pause status, respectively. They are only used for testing
//            case U4DEngine::macKeyP:
//            {
//
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//                    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
//
//                    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
//                    U4DEngine::U4DScene *scene=sceneManager->getCurrentScene();
//                    U4DEngine::U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
//
//                    if(sceneStateManager->getCurrentState()==U4DEngine::U4DSceneEditingState::sharedInstance()){
//                        //change scene state to edit mode
//                        scene->getSceneStateManager()->changeState(U4DEngine::U4DScenePlayState::sharedInstance());
//
//                    }else if(sceneStateManager->getCurrentState()==U4DEngine::U4DScenePlayState::sharedInstance()){
//
//                        scene->setPauseScene(false);
//
//                    }
//
//                    scene->setAnchorMouse(true);
//
//                    [NSCursor hide];
//
//                    logger->log("Game was resumed");
//
//                }
//
//            }
//                break;
//
//            case U4DEngine::macKeyU:
//            {
//
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//                    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
//
//                    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
//                    U4DEngine::U4DScene *scene=sceneManager->getCurrentScene();
//
//                    U4DEngine::U4DSceneStateManager *sceneStateManager=scene->getSceneStateManager();
//
//                    if (sceneStateManager->getCurrentState()==U4DEngine::U4DScenePlayState::sharedInstance()) {
//
//                        //change scene state to pause
//                        scene->setPauseScene(true);
//
//                        logger->log("Game was paused");
//
//                        scene->setAnchorMouse(false);
//
//                        [NSCursor unhide];
//
//                    }
//
//                }
//
//            }
//                break;
//#endif
//
//            case U4DEngine::macShiftKey:
//            {
//                //4. If button was pressed
//                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
//
//
//                    //5. If button was released
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
//
//
//                }
//
//            }
//                break;
//
//            case U4DEngine::padButtonA:
//
//                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
//
//
//                }
//
//                break;
//
//            case U4DEngine::padButtonB:
//
//                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
//
//
//
//                }
//
//                break;
//
//            case U4DEngine::padRightTrigger:
//
//                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
//
//                }
//
//                break;
//
//            case U4DEngine::padLeftTrigger:
//
//                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
//
//
//                }
//
//            break;
//
//            case U4DEngine::padLeftThumbstick:
//
//                if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
//
//                   //Get joystick direction
////                   U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,0.0,controllerInputMessage.joystickDirection.y);
////                    U4DEngine::U4DVector3n axis(0.0,1.0,0.0);
////                    pPlayer->rotateBy(joystickDirection.x, axis);
//
//
//               }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
//
//
//
//
//               }
//
//            break;
//
//            case U4DEngine::mouse:
//            {
//
//                if(controllerInputMessage.inputElementAction==U4DEngine::mouseActiveDelta){
//
//                    //SNIPPET TO USE FOR MOUSE DELTA POSITION
//
//                    //Get the delta movement of the mouse
//                    U4DEngine::U4DVector2n delta=controllerInputMessage.mouseDeltaPosition;
//                    //the y delta should be flipped
//                    delta.y*=-1.0;
//
//                    //The following snippet will determine which way to rotate the model depending on the motion of the mouse
//
//                    delta.normalize();
//
//                    U4DEngine::U4DVector3n axis;
//
//                    U4DEngine::U4DVector3n mousedirection(delta.x,0.0,delta.y);
//
//
//
//                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){
//
//                    //std::cout<<"Mouse stopped"<<std::endl;
//
//                }
//
//            }
//
//                break;
//
//            default:
//                break;
//        }
//
//    }
    
} 
