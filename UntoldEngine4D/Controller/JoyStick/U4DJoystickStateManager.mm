//
//  U4DJoystickStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/16/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DJoystickStateManager.h"

#include "U4DJoyStick.h"

namespace U4DEngine {
    
    U4DJoystickStateManager::U4DJoystickStateManager(U4DJoyStick *uJoyStick):joystick(uJoyStick),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DJoystickStateManager::~U4DJoystickStateManager(){
        
    }
    
    void U4DJoystickStateManager::changeState(U4DJoystickStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(joystick);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(joystick);
        
    }
    
    void U4DJoystickStateManager::update(double dt){
        
        currentState->execute(joystick, dt);
        
    }
    
    U4DJoystickStateInterface *U4DJoystickStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
