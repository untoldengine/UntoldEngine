//
//  U4DPadJoystickStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/10/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#include "U4DPadJoystickStateManager.h"
#include "U4DPadJoystick.h"

namespace U4DEngine {
    
    U4DPadJoystickStateManager::U4DPadJoystickStateManager(U4DPadJoystick *uPadJoystick):padJoystick(uPadJoystick),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DPadJoystickStateManager::~U4DPadJoystickStateManager(){
        
    }
    
    void U4DPadJoystickStateManager::changeState(U4DPadJoystickStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(padJoystick);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(padJoystick);
        
    }
    
    void U4DPadJoystickStateManager::update(double dt){
        
        currentState->execute(padJoystick, dt);
        
    }
    
    U4DPadJoystickStateInterface *U4DPadJoystickStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
