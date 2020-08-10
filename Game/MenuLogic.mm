//
//  MenuLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "MenuLogic.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "U4DSceneManager.h"
#include "LevelOneScene.h"


using namespace U4DEngine;

MenuLogic::MenuLogic():stickBounce(false){
    
}

MenuLogic::~MenuLogic(){
    
}

void MenuLogic::update(double dt){
    
}

void MenuLogic::init(){
    
    //Get the world-view component
    pMenu=dynamic_cast<MenuWorld*>(getGameWorld());
    
}

void MenuLogic::changeToSelection(){
    
    if (pMenu->getState()==selectingOptionsInMenu) {
        
        pMenu->playOption();
    
    }else if(pMenu->getState()==selectingKit){
        
        //get instance of scene manager
        U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();

        //Switch to other Menu Screen
        LevelOneScene *levelOneScene=new LevelOneScene();

        sceneManager->changeScene(levelOneScene);
    }
    
}

void MenuLogic::receiveUserInputUpdate(void *uData){
    
    CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
            
        //2. Determine what was pressed, buttons, keys or joystick
        
    if(pMenu!=nullptr){
     
        switch (controllerInputMessage.inputElementType) {
                
            case U4DEngine::padButtonA:
            
            if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                
                changeToSelection();
                
            }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                
            }
            
            break;
                
            case U4DEngine::uiButton:
            
            if(controllerInputMessage.inputElementAction==U4DEngine::uiButtonPressed){
                
                //pass
                if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
                    
                    changeToSelection();
                    
                }
                
            }else if (controllerInputMessage.inputElementAction==U4DEngine::uiButtonReleased){
            
            
            }
            
            break;
                
            case U4DEngine::padButtonB: //Go back to previous layer
            
            if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                
                if(pMenu->getState()!=selectingOptionsInMenu){
                    
                    //Remove layer
                    pMenu->removeActiveLayer();
                    
                }
                
            }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                
            }
            
            break;
                
            case U4DEngine::padLeftThumbstick:
            
                if(controllerInputMessage.inputElementAction==U4DEngine::padThumbstickMoved){
                    
                    //Get joystick direction
                    U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,controllerInputMessage.joystickDirection.y,0.0);
                    
                    if (stickBounce==false && (joystickDirection.y==1.0||joystickDirection.y==-1.0 || joystickDirection.x==1.0||joystickDirection.x==-1.0)) {
                        
                        if (pMenu->getState()==selectingOptionsInMenu) {
                            pMenu->selectOptionInMenu(joystickDirection.y);
                            
                        }
                        
                        if (pMenu->getState()==selectingKit) {
                            pMenu->selectKit(joystickDirection.x);
                        }
                        
                        stickBounce=true;
                        
                    }
                    
                }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                    
                    stickBounce=false;
                }
            
            break;
                
            case U4DEngine::uiJoystick:
            {
                
                if (controllerInputMessage.elementUIName.compare("joystick")==0 ) {
                    
                    if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickMoved){

                        //Get joystick direction
                        U4DEngine::U4DVector3n joystickDirection(controllerInputMessage.joystickDirection.x,controllerInputMessage.joystickDirection.y,0.0);
                        
                        joystickDirection.normalize();
                        joystickDirection.y=round(joystickDirection.y);
                        joystickDirection.x=round(joystickDirection.x);
                        
                        if (stickBounce==false && (joystickDirection.y>=1.0||joystickDirection.y==-1.0 || joystickDirection.x==1.0||joystickDirection.x==-1.0)) {
                            
                            if (pMenu->getState()==selectingOptionsInMenu) {
                                pMenu->selectOptionInMenu(joystickDirection.y);
                                
                            }
                            
                            if (pMenu->getState()==selectingKit) {
                                pMenu->selectKit(joystickDirection.x);
                            }
                            
                            stickBounce=true;
                            
                        }
                    
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickReleased){

                        stickBounce=false;

                    }
                    
                }
                

            }
                break;
                
            case U4DEngine::macSpaceKey:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    changeToSelection();
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                    
                }
            }
                
                break;
                
            case U4DEngine::macShiftKey: //Go back to previous layer
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    if(pMenu->getState()!=selectingOptionsInMenu){
                        
                        //Remove layer
                        pMenu->removeActiveLayer();
                        
                    }

                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    

                }
                
            }
                break;
                
            case U4DEngine::macArrowKey:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macArrowKeyActive) {
                    
                    U4DEngine::U4DVector2n arrowKeyDirection=controllerInputMessage.arrowKeyDirection;
                    
                    //Get arrow key direction
                    if (stickBounce==false && (arrowKeyDirection.y==1.0||arrowKeyDirection.y==-1.0 || arrowKeyDirection.x==1.0||arrowKeyDirection.x==-1.0)) {
                        
                        if (pMenu->getState()==selectingOptionsInMenu) {
                            pMenu->selectOptionInMenu(arrowKeyDirection.y);
                            
                        }
                        
                        if (pMenu->getState()==selectingKit) {
                            pMenu->selectKit(arrowKeyDirection.x);
                        }
                        
                        stickBounce=true;
                        
                    }
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macArrowKeyReleased){
                    
                    stickBounce=false;
                    
                }
            }
                
                break;
                
            default:
                break;
                
        }
        
    }
        
}
