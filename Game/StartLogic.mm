//
//  StartLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/12/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#include "StartLogic.h"
#include "CommonProtocols.h"

using namespace U4DEngine;

StartLogic::StartLogic(){
    
}

StartLogic::~StartLogic(){
    
}

void StartLogic::update(double dt){
    
}

void StartLogic::init(){
    
}

void StartLogic::receiveUserInputUpdate(void *uData){
    
    CONTROLLERMESSAGE controllerInputMessage=*(CONTROLLERMESSAGE*)uData;
            
        //2. Determine what was pressed, buttons, keys or joystick
        
    
        
        switch (controllerInputMessage.inputElementType) {
            
            case U4DEngine::mouseLeftButton:
            {
                if (controllerInputMessage.elementUIName.compare("start")!=0) {
                    
                    //4. If button was pressed
                    if (controllerInputMessage.inputElementAction==U4DEngine::mouseButtonPressed) {
                        
                        std::cout<<"mouse clicked"<<std::endl;
                            
                        //5. If button was released
                    }else if(controllerInputMessage.inputElementAction==U4DEngine::mouseButtonReleased){
                        
                    
                        
                    }
                    
                }
            }
                
                break;
                
            default:
                break;
                
        }
    
        
}
