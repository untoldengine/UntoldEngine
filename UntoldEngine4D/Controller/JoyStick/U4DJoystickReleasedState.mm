//
//  U4DJoystickReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DJoystickReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DJoystickReleasedState* U4DJoystickReleasedState::instance=0;
    
    U4DJoystickReleasedState::U4DJoystickReleasedState(){
        
    }
    
    U4DJoystickReleasedState::~U4DJoystickReleasedState(){
        
    }
    
    U4DJoystickReleasedState* U4DJoystickReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DJoystickReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DJoystickReleasedState::enter(U4DJoyStick *uJoyStick){
        
        uJoyStick->translateTo(uJoyStick->originalPosition);
        
        uJoyStick->joyStickImage.translateTo(uJoyStick->originalPosition);
        
        uJoyStick->dataMagnitude=0.0;
        
        if (uJoyStick->pCallback!=NULL) {
            uJoyStick->action();
        }
        
        if (uJoyStick->controllerInterface!=NULL) {
            uJoyStick->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DJoystickReleasedState::execute(U4DJoyStick *uJoyStick, double dt){
        
        
    }
    
    void U4DJoystickReleasedState::exit(U4DJoyStick *uJoyStick){
        
    }
    
}
