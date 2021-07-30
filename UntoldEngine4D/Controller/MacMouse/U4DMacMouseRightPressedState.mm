//
//  U4DMacMouseRightPressedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMouseRightPressedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacMouseRightPressedState* U4DMacMouseRightPressedState::instance=0;
    
    U4DMacMouseRightPressedState::U4DMacMouseRightPressedState(){
        
    }
    
    U4DMacMouseRightPressedState::~U4DMacMouseRightPressedState(){
        
    }
    
    U4DMacMouseRightPressedState* U4DMacMouseRightPressedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMouseRightPressedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMouseRightPressedState::enter(U4DMacMouse *uMacMouse){
        
        uMacMouse->previousDataPosition=uMacMouse->dataPosition;
        
        uMacMouse->action(U4DEngine::mouseRightButtonPressed);
        
        if (uMacMouse->controllerInterface !=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMouseRightPressedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        
    }
    
    void U4DMacMouseRightPressedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
