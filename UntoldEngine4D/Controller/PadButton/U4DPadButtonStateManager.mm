//
//  U4DPadButtonStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/8/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DPadButtonStateManager.h"
#include "U4DPadButton.h"

namespace U4DEngine {
    
    U4DPadButtonStateManager::U4DPadButtonStateManager(U4DPadButton *uPadButton):padButton(uPadButton),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DPadButtonStateManager::~U4DPadButtonStateManager(){
        
    }
    
    void U4DPadButtonStateManager::changeState(U4DPadButtonStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(padButton);
        }
        
        //The game pad constantly sends a message to change the state. To prevent it
        //check if the current state is not the same as the new state
        if(currentState!=uState){
            
            //change state to new state
            currentState=uState;
            
            //call the entry method of the new state
            currentState->enter(padButton);
            
        }
        
    }
    
    void U4DPadButtonStateManager::update(double dt){
        
        currentState->execute(padButton, dt);
        
    }
    
    U4DPadButtonStateInterface *U4DPadButtonStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
