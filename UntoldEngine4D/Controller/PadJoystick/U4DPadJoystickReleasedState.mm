//
//  U4DPadJoystickReleasedState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DPadJoystickReleasedState.h"
#include "U4DControllerInterface.h"

namespace U4DEngine {
    
    U4DPadJoystickReleasedState* U4DPadJoystickReleasedState::instance=0;
    
    U4DPadJoystickReleasedState::U4DPadJoystickReleasedState(){
        
    }
    
    U4DPadJoystickReleasedState::~U4DPadJoystickReleasedState(){
        
    }
    
    U4DPadJoystickReleasedState* U4DPadJoystickReleasedState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPadJoystickReleasedState();
        }
        
        return instance;
        
    }
    
    void U4DPadJoystickReleasedState::enter(U4DPadJoystick *uPadJoystick){
        
        uPadJoystick->dataMagnitude=0.0;

        if (uPadJoystick->pCallback!=NULL) {
            uPadJoystick->action();
        }

        if (uPadJoystick->controllerInterface!=NULL) {
            uPadJoystick->controllerInterface->setReceivedAction(true);
        }
        
    }
    
    void U4DPadJoystickReleasedState::execute(U4DPadJoystick *uPadJoystick, double dt){
        
        
    }
    
    void U4DPadJoystickReleasedState::exit(U4DPadJoystick *uPadJoystick){
        
    }
    
}
