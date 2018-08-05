//
//  U4DMacArrowKeyStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/5/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DMacArrowKeyStateManager.h"
#include "U4DMacArrowKey.h"

namespace U4DEngine {
    
    U4DMacArrowKeyStateManager::U4DMacArrowKeyStateManager(U4DMacArrowKey *uMacArrowKey):padJoystick(uMacArrowKey),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DMacArrowKeyStateManager::~U4DMacArrowKeyStateManager(){
        
    }
    
    void U4DMacArrowKeyStateManager::changeState(U4DMacArrowKeyStateInterface *uState){
        
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
    
    void U4DMacArrowKeyStateManager::update(double dt){
        
        currentState->execute(padJoystick, dt);
        
    }
    
    U4DMacArrowKeyStateInterface *U4DMacArrowKeyStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
