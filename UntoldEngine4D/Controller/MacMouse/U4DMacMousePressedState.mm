//
//  U4DMacMousePressedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacMousePressedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DMacMousePressedState* U4DMacMousePressedState::instance=0;
    
    U4DMacMousePressedState::U4DMacMousePressedState(){
        
    }
    
    U4DMacMousePressedState::~U4DMacMousePressedState(){
        
    }
    
    U4DMacMousePressedState* U4DMacMousePressedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DMacMousePressedState();
        }
        
        return instance;
        
    }
    
    void U4DMacMousePressedState::enter(U4DMacMouse *uMacMouse){
        
        U4DEngine::U4DVector3n mouseAxis(uMacMouse->mouseAxis.x,uMacMouse->mouseAxis.y, 0.0);
        
        uMacMouse->previousDataPosition=mouseAxis;
        
        if (uMacMouse->pCallback!=NULL) {
            uMacMouse->action();
        }
        
        
        if (uMacMouse->controllerInterface !=NULL) {
            uMacMouse->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DMacMousePressedState::execute(U4DMacMouse *uMacMouse, double dt){
        
        
    }
    
    void U4DMacMousePressedState::exit(U4DMacMouse *uMacMouse){
        
    }
    
}
