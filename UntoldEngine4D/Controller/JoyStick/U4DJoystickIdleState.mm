//
//  U4DJoystickIdleState.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DJoystickIdleState.h"

namespace U4DEngine {
    
    U4DJoystickIdleState* U4DJoystickIdleState::instance=0;
    
    U4DJoystickIdleState::U4DJoystickIdleState(){
        
    }
    
    U4DJoystickIdleState::~U4DJoystickIdleState(){
        
    }
    
    U4DJoystickIdleState* U4DJoystickIdleState::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DJoystickIdleState();
        }
        
        return instance;
        
    }
    
    void U4DJoystickIdleState::enter(U4DJoyStick *uJoyStick){
        
    }
    
    void U4DJoystickIdleState::execute(U4DJoyStick *uJoyStick, double dt){
        
        
    }
    
    void U4DJoystickIdleState::exit(U4DJoyStick *uJoyStick){
        
    }
    
}
