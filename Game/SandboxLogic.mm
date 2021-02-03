//
//  SandboxLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/13/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "SandboxLogic.h"
#include "U4DDirector.h"
#include "CommonProtocols.h"
#include "UserCommonProtocols.h"
#include "SandboxWorld.h"
#include "U4DDebugger.h"

SandboxLogic::SandboxLogic():showBroadPhaseVolume(false),showNarrowPhaseVolume(false){
    
}

SandboxLogic::~SandboxLogic(){
    
}

void SandboxLogic::update(double dt){
    
    
}

void SandboxLogic::init(){
    
    //1. Get a pointer to the LevelOneWorld object
    SandboxWorld *pEarth=dynamic_cast<SandboxWorld*>(getGameWorld());
    
    //2. Search for the player object
    pAstronaut=dynamic_cast<U4DEngine::U4DGameObject*>(pEarth->searchChild("astronaut"));
}


void SandboxLogic::receiveUserInputUpdate(void *uData){
    
    U4DEngine::CONTROLLERMESSAGE controllerInputMessage=*(U4DEngine::CONTROLLERMESSAGE*)uData;
    
        switch (controllerInputMessage.inputElementType) {
            
            case U4DEngine::uiButton:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiButtonPressed){
                    
                    
                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
                        
                        //std::cout<<"Button A pressed"<<std::endl;
                    
                    
                    }
                    
                }else if (controllerInputMessage.inputElementAction==U4DEngine::uiButtonReleased){
                
                    if (controllerInputMessage.elementUIName.compare("buttonA")==0) {
                        
                        //std::cout<<"Button A released"<<std::endl;
                    
                    
                    }
                
                }
                
                break;
                
            case U4DEngine::uiSlider:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiSliderMoved){
                    
                    
                    if (controllerInputMessage.elementUIName.compare("sliderA")==0) {
                        
                        
                    
                    }else if(controllerInputMessage.elementUIName.compare("sliderB")==0){
                        
                        
                        
                    }
                    
                }
                
                break;
            
            case U4DEngine::uiJoystick:
            
            if(controllerInputMessage.inputElementAction==U4DEngine::uiJoystickMoved){
                
                
                if (controllerInputMessage.elementUIName.compare("joystick")==0) {
                    
                    
                
                }
                
            }else if (controllerInputMessage.inputElementAction==U4DEngine::uiJoystickReleased){
            
                if (controllerInputMessage.elementUIName.compare("joystick")==0) {
                    
                    //std::cout<<"joystick released"<<std::endl;
                
                
                }
            
            }
            
            break;
                
            case U4DEngine::uiCheckbox:
                
                if(controllerInputMessage.inputElementAction==U4DEngine::uiCheckboxPressed){
                    
                    
                    if (controllerInputMessage.elementUIName.compare("checkboxA")==0) {
                        
                        
                    
                    }else if(controllerInputMessage.elementUIName.compare("checkboxB")==0){
                     
                        
                    }
                    
                }
                
                break;
                
            case U4DEngine::mouseLeftButton:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::mouseButtonPressed) {
                    
                    //std::cout<<"left clicked"<<std::endl;
                        
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseButtonReleased){
                    
                    //std::cout<<"left released"<<std::endl;
                    
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
                    
                    U4DEngine::U4DDebugger *debugger=U4DEngine::U4DDebugger::sharedInstance();
                    
                    debugger->reloadShader("compositionpipeline", "/Users/haroldserrano/Downloads/compositionReloadShader.metal", "vertexCompShader", "fragmentCompShader");
                }
            }
                break;
                
            case U4DEngine::macKeyS:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                    
                }
                
            }
                break;
                
                
            case U4DEngine::macShiftKey:
            {
                //4. If button was pressed
                if (controllerInputMessage.inputElementAction==U4DEngine::macKeyPressed) {
                    
                    
                    //5. If button was released
                }else if(controllerInputMessage.inputElementAction==U4DEngine::macKeyReleased){
                    
                    
                }
                
            }
                break;
                
            case U4DEngine::padButtonA:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                     
                    
                }else if(controllerInputMessage.inputElementAction==U4DEngine::padButtonReleased){
                    
                }
                
                break;
                
            case U4DEngine::padButtonB:
                
                if (controllerInputMessage.inputElementAction==U4DEngine::padButtonPressed) {
                    
                    
                    
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
                   
                    
                   
                   
               }else if (controllerInputMessage.inputElementAction==U4DEngine::padThumbstickReleased){
                   
                   
                   
                   
               }
            
            break;
                
            case U4DEngine::mouse:
            {
                
                if(controllerInputMessage.inputElementAction==U4DEngine::mouseActive){
                
                    //SNIPPET TO USE FOR MOUSE ABSOLUTE POSITION
                    
                    U4DEngine::U4DVector3n mousedirection(controllerInputMessage.inputPosition.x,0.0,controllerInputMessage.inputPosition.y);

                    //std::cout<<"Mouse moving"<<std::endl;

                }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseInactive){
                    
                    //std::cout<<"Mouse stopped"<<std::endl;
                }
                
            }
                
                break;
                
            default:
                break;
        }
    
} 
