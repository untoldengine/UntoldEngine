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

void MenuLogic::receiveUserInputUpdate(void *uData){
    
    CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
            
        //2. Determine what was pressed, buttons, keys or joystick
        
    if(pMenu!=nullptr){
     
        switch (controllerInputMessage.inputElementType) {
                
            case U4DEngine::padButtonA:
            
            if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                
                if (pMenu->getState()==selectingOptionsInMenu) {
                    
                    pMenu->playOption();
                
                }else if(pMenu->getState()==selectingKit){
                    
                    //get instance of scene manager
                    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();

                    //Switch to other Menu Screen
                    LevelOneScene *levelOneScene=new LevelOneScene();

                    sceneManager->changeScene(levelOneScene);
                }
                
            }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                
            }
            
            break;
                
            case U4DEngine::padButtonB:
            
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
                
            case U4DEngine::padRightShoulder:
            
            if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                
                
            }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                
            }
            
            break;
                
            case U4DEngine::padLeftShoulder:
            
            if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                
                
            }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                
            }
            
            break;
                
            default:
                break;
                
        }
        
    }
        
}
