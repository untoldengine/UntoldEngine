//
//  U4DButtonStateManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#include "U4DButtonStateManager.h"
#include "U4DButton.h"

namespace U4DEngine {
    
    U4DButtonStateManager::U4DButtonStateManager(U4DButton *uButton):button(uButton),previousState(NULL),currentState(NULL){
        
        
    }
    
    U4DButtonStateManager::~U4DButtonStateManager(){
        
    }
    
    void U4DButtonStateManager::changeState(U4DButtonStateInterface *uState){
        
        //keep a record of previous state
        previousState=currentState;
        
        //call the exit method of the existing state
        if (currentState!=NULL) {
            currentState->exit(button);
        }
        
        //change state to new state
        currentState=uState;
        
        //call the entry method of the new state
        currentState->enter(button);
        
    }
    
    void U4DButtonStateManager::update(double dt){
        
        currentState->execute(button, dt);
        
    }
    
    U4DButtonStateInterface *U4DButtonStateManager::getCurrentState(){
        
        return currentState;
    }
    
}
