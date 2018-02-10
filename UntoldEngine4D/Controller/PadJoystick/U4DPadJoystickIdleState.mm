//
//  U4DPadJoystickIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DPadJoystickIdleState.h"

namespace U4DEngine {
    
    U4DPadJoystickIdleState* U4DPadJoystickIdleState::instance=0;
    
    U4DPadJoystickIdleState::U4DPadJoystickIdleState(){
        
    }
    
    U4DPadJoystickIdleState::~U4DPadJoystickIdleState(){
        
    }
    
    U4DPadJoystickIdleState* U4DPadJoystickIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DPadJoystickIdleState();
        }
        
        return instance;
        
    }
    
    void U4DPadJoystickIdleState::enter(U4DPadJoystick *uPadJoystick){
        
    }
    
    void U4DPadJoystickIdleState::execute(U4DPadJoystick *uPadJoystick, double dt){
        
        
    }
    
    void U4DPadJoystickIdleState::exit(U4DPadJoystick *uPadJoystick){
        
    }
    
}
